import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, date
from typing import Iterator

from src.config import config
from src.models import ActivityRecord, DailySummary, AppSummary

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS activity_log (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now','localtime')),
    app_name       TEXT NOT NULL,
    bundle_id      TEXT,
    is_idle        INTEGER NOT NULL DEFAULT 0,
    idle_seconds   REAL,
    poll_interval  INTEGER NOT NULL DEFAULT 15
);

CREATE TABLE IF NOT EXISTS daily_summary (
    date                  TEXT PRIMARY KEY,
    day_of_week           INTEGER NOT NULL,
    total_active_minutes  REAL NOT NULL DEFAULT 0,
    total_idle_minutes    REAL NOT NULL DEFAULT 0,
    overtime_minutes      REAL NOT NULL DEFAULT 0,
    first_activity        TEXT,
    last_activity         TEXT,
    work_category         TEXT NOT NULL DEFAULT 'regular'
);

CREATE TABLE IF NOT EXISTS app_daily_summary (
    date              TEXT NOT NULL,
    app_name          TEXT NOT NULL,
    active_minutes    REAL NOT NULL DEFAULT 0,
    regular_minutes   REAL NOT NULL DEFAULT 0,
    overtime_minutes  REAL NOT NULL DEFAULT 0,
    PRIMARY KEY (date, app_name)
);

CREATE TABLE IF NOT EXISTS settings (
    id                   INTEGER PRIMARY KEY CHECK (id = 1),
    core_start_hour      INTEGER NOT NULL DEFAULT 9,
    core_start_minute    INTEGER NOT NULL DEFAULT 0,
    core_end_hour        INTEGER NOT NULL DEFAULT 18,
    core_end_minute      INTEGER NOT NULL DEFAULT 0,
    work_days            TEXT NOT NULL DEFAULT '0,1,2,3',
    idle_timeout_seconds INTEGER NOT NULL DEFAULT 600
);

CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_log(timestamp);
"""

SCHEMA_VERSION = 2

# Each migration brings the DB from (version - 1) to version.
# Statements use try/except individually so fresh installs (where SCHEMA_SQL
# already created the full schema) skip gracefully.
MIGRATIONS: dict[int, list[str]] = {
    1: [
        "ALTER TABLE app_daily_summary ADD COLUMN regular_minutes REAL NOT NULL DEFAULT 0",
        "ALTER TABLE app_daily_summary ADD COLUMN overtime_minutes REAL NOT NULL DEFAULT 0",
    ],
    2: [
        "ALTER TABLE settings ADD COLUMN core_start_minute INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE settings ADD COLUMN core_end_minute INTEGER NOT NULL DEFAULT 0",
    ],
}


def _migrate(conn: sqlite3.Connection):
    """Apply pending schema migrations using PRAGMA user_version."""
    current = conn.execute("PRAGMA user_version").fetchone()[0]
    if current >= SCHEMA_VERSION:
        return
    for version in sorted(MIGRATIONS.keys()):
        if version <= current:
            continue
        for sql in MIGRATIONS[version]:
            try:
                conn.execute(sql)
            except sqlite3.OperationalError as e:
                if "duplicate column" not in str(e) and "already exists" not in str(e):
                    raise  # Only skip "already exists" errors (fresh install)
    conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    conn.commit()


@contextmanager
def get_connection() -> Iterator[sqlite3.Connection]:
    """Create a new SQLite connection with WAL mode enabled. Use as a context manager."""
    config.db_path.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(config.db_path.parent, 0o700)
    conn = sqlite3.connect(str(config.db_path))
    os.chmod(config.db_path, 0o600)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def init_db():
    """Initialize database schema, run migrations, and seed default settings."""
    with get_connection() as conn:
        conn.executescript(SCHEMA_SQL)
        _migrate(conn)
        # Seed default settings row if missing
        conn.execute(
            "INSERT OR IGNORE INTO settings (id) VALUES (1)"
        )
        conn.commit()
    config.reload_from_db()


def log_activity(record: ActivityRecord):
    """Insert a single activity record."""
    with get_connection() as conn:
        conn.execute(
            """INSERT INTO activity_log (timestamp, app_name, bundle_id, is_idle, idle_seconds, poll_interval)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                record.timestamp.strftime("%Y-%m-%dT%H:%M:%S"),
                record.app_name,
                record.bundle_id,
                int(record.is_idle),
                record.idle_seconds,
                record.poll_interval,
            ),
        )
        conn.commit()


def update_daily_summaries(target_date: str | None = None):
    """Recompute daily_summary and app_daily_summary for a given date (default: today)."""
    if target_date is None:
        target_date = date.today().isoformat()

    with get_connection() as conn:
        # Compute totals from raw activity_log
        row = conn.execute(
            """SELECT
                COUNT(CASE WHEN is_idle = 0 THEN 1 END) as active_polls,
                COUNT(CASE WHEN is_idle = 1 THEN 1 END) as idle_polls,
                MIN(time(timestamp)) as first_activity,
                MAX(time(timestamp)) as last_activity,
                AVG(poll_interval) as avg_interval
            FROM activity_log
            WHERE date(timestamp) = ?""",
            (target_date,),
        ).fetchone()

        if row is None or (row["active_polls"] == 0 and row["idle_polls"] == 0):
            return

        avg_interval = row["avg_interval"] or config.polling_interval_seconds
        active_minutes = (row["active_polls"] * avg_interval) / 60
        idle_minutes = (row["idle_polls"] * avg_interval) / 60

        # Compute overtime: count active polls outside core hours
        dt = datetime.strptime(target_date, "%Y-%m-%d")
        weekday = dt.weekday()
        category = config.get_work_category(weekday, 12)  # day-level category

        # For overtime calculation, count active polls outside core hours
        # Use minute-granularity: compare HH*60+MM against core start/end in minutes
        core_start_min = config.schedule.core_start_hour * 60 + config.schedule.core_start_minute
        core_end_min = config.schedule.core_end_hour * 60 + config.schedule.core_end_minute
        overtime_row = conn.execute(
            """SELECT COUNT(*) as cnt FROM activity_log
            WHERE date(timestamp) = ? AND is_idle = 0
            AND (CAST(strftime('%H', timestamp) AS INTEGER) * 60
                 + CAST(strftime('%M', timestamp) AS INTEGER) < ?
                 OR CAST(strftime('%H', timestamp) AS INTEGER) * 60
                 + CAST(strftime('%M', timestamp) AS INTEGER) >= ?)""",
            (target_date, core_start_min, core_end_min),
        ).fetchone()

        # On non-work days, all active time is overtime
        if category == "overtime":
            overtime_minutes = active_minutes
        else:
            overtime_minutes = (overtime_row["cnt"] * avg_interval) / 60

        conn.execute(
            """INSERT OR REPLACE INTO daily_summary
            (date, day_of_week, total_active_minutes, total_idle_minutes,
             overtime_minutes, first_activity, last_activity, work_category)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                target_date, weekday, active_minutes, idle_minutes,
                overtime_minutes, row["first_activity"], row["last_activity"],
                category,
            ),
        )

        # Update per-app summaries with regular/overtime split
        is_work_day = weekday in config.schedule.work_days
        app_rows = conn.execute(
            """SELECT app_name,
                COUNT(*) as polls,
                AVG(poll_interval) as avg_int,
                COUNT(CASE WHEN CAST(strftime('%H', timestamp) AS INTEGER) * 60
                                + CAST(strftime('%M', timestamp) AS INTEGER) >= ?
                          AND CAST(strftime('%H', timestamp) AS INTEGER) * 60
                              + CAST(strftime('%M', timestamp) AS INTEGER) < ?
                     THEN 1 END) as core_polls
            FROM activity_log
            WHERE date(timestamp) = ? AND is_idle = 0
            GROUP BY app_name""",
            (core_start_min, core_end_min, target_date),
        ).fetchall()

        for app_row in app_rows:
            ai = app_row["avg_int"] or avg_interval
            app_total = (app_row["polls"] * ai) / 60
            if is_work_day:
                app_regular = (app_row["core_polls"] * ai) / 60
                app_overtime = app_total - app_regular
            else:
                app_regular = 0.0
                app_overtime = app_total
            conn.execute(
                """INSERT OR REPLACE INTO app_daily_summary
                (date, app_name, active_minutes, regular_minutes, overtime_minutes)
                VALUES (?, ?, ?, ?, ?)""",
                (target_date, app_row["app_name"], app_total, app_regular, app_overtime),
            )

        conn.commit()


def _row_to_summary(r: sqlite3.Row) -> DailySummary:
    return DailySummary(
        date=r["date"], day_of_week=r["day_of_week"],
        total_active_minutes=r["total_active_minutes"],
        total_idle_minutes=r["total_idle_minutes"],
        overtime_minutes=r["overtime_minutes"],
        first_activity=r["first_activity"], last_activity=r["last_activity"],
        work_category=r["work_category"],
    )


def get_daily_summary(target_date: str) -> DailySummary | None:
    """Get the daily summary for a given date."""
    with get_connection() as conn:
        row = conn.execute(
            "SELECT * FROM daily_summary WHERE date = ?", (target_date,)
        ).fetchone()
    if row is None:
        return None
    return _row_to_summary(row)


def get_week_summaries(iso_year: int, iso_week: int) -> list[DailySummary]:
    """Get all daily summaries for a given ISO week."""
    with get_connection() as conn:
        rows = conn.execute(
            """SELECT * FROM daily_summary
            WHERE strftime('%G', date) = ? AND strftime('%V', date) = ?
            ORDER BY date""",
            (str(iso_year), f"{iso_week:02d}"),
        ).fetchall()
    return [_row_to_summary(r) for r in rows]


def get_app_summaries(target_date: str) -> list[AppSummary]:
    """Get per-app breakdown for a given date."""
    with get_connection() as conn:
        rows = conn.execute(
            """SELECT * FROM app_daily_summary WHERE date = ? ORDER BY active_minutes DESC""",
            (target_date,),
        ).fetchall()
    return [
        AppSummary(
            date=r["date"],
            app_name=r["app_name"],
            active_minutes=r["active_minutes"],
            regular_minutes=r["regular_minutes"],
            overtime_minutes=r["overtime_minutes"],
        )
        for r in rows
    ]


def get_monthly_summaries(year: int, month: int) -> list[DailySummary]:
    """Get all daily summaries for a given month."""
    with get_connection() as conn:
        rows = conn.execute(
            """SELECT * FROM daily_summary
            WHERE strftime('%Y', date) = ? AND strftime('%m', date) = ?
            ORDER BY date""",
            (str(year), f"{month:02d}"),
        ).fetchall()
    return [_row_to_summary(r) for r in rows]


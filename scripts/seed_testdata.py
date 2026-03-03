#!/usr/bin/env python3
"""Generate realistic test data for the Overtime Tracker SwiftUI app.

Creates ~/.overtime-tracker/overtime.db with 2 weeks of data (2026-02-17 to 2026-03-02).
Run: venv/bin/python scripts/seed_testdata.py
"""

import sqlite3
import random
from datetime import datetime, timedelta, date
from pathlib import Path

DB_PATH = Path.home() / ".overtime-tracker" / "overtime.db"

SCHEMA_SQL = """
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS activity_log (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp      TEXT NOT NULL,
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
    core_end_hour        INTEGER NOT NULL DEFAULT 18,
    work_days            TEXT NOT NULL DEFAULT '0,1,2,3',
    idle_timeout_seconds INTEGER NOT NULL DEFAULT 600
);

CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_log(timestamp);
"""

# Realistic app distribution: (app_name, bundle_id, weight_core, weight_overtime)
APPS = [
    ("Xcode", "com.apple.dt.Xcode", 30, 15),
    ("Terminal", "com.apple.Terminal", 20, 35),
    ("Claude", "com.anthropic.claude", 15, 25),
    ("Slack", "com.tinyspeck.slackmacgap", 12, 2),
    ("Mail", "com.apple.mail", 8, 1),
    ("Safari", "com.apple.Safari", 5, 8),
    ("DataGrip", "com.jetbrains.datagrip", 4, 10),
    ("Figma", "com.figma.Desktop", 3, 2),
]

CORE_START = 9
CORE_END = 18
WORK_DAYS = {0, 1, 2, 3}  # Mo-Do

# Fixed empty days (vacation/sick) — 2026-02-21 (Fr) and 2026-02-25 (Di)
EMPTY_DAYS = {date(2026, 2, 21), date(2026, 2, 25)}


def weighted_choice(apps, is_overtime: bool) -> str:
    idx = 3 if is_overtime else 2
    weights = [a[idx] for a in apps]
    chosen = random.choices(apps, weights=weights, k=1)[0]
    return chosen[0]


def generate_day(d: date) -> dict | None:
    weekday = d.weekday()  # 0=Mo ... 6=So

    # Fixed empty days
    if d in EMPTY_DAYS:
        return None

    is_work_day = weekday in WORK_DAYS
    is_weekend = weekday >= 5

    if is_weekend:
        # ~30% chance of weekend work
        if random.random() > 0.30:
            return None
        active_hours = random.uniform(1.0, 3.0)
        start_hour = random.uniform(10.0, 15.0)
        end_hour = start_hour + active_hours
        overtime_ratio = 1.0
    elif weekday == 4:  # Friday
        # ~50% chance of Friday work
        if random.random() > 0.50:
            return None
        active_hours = random.uniform(2.0, 5.0)
        start_hour = random.uniform(9.0, 11.0)
        end_hour = start_hour + active_hours
        overtime_ratio = 1.0  # Friday not in work_days
    elif not is_work_day:
        return None
    else:
        # Regular work day (Mo-Do)
        start_hour = random.gauss(8.7, 0.4)
        start_hour = max(7.5, min(10.0, start_hour))

        end_hour = random.gauss(19.3, 0.7)
        end_hour = max(17.5, min(21.5, end_hour))

        total_span = end_hour - start_hour
        idle_ratio = random.uniform(0.10, 0.18)
        active_hours = total_span * (1 - idle_ratio)

        before_core = max(0, CORE_START - start_hour)
        after_core = max(0, end_hour - CORE_END)
        overtime_hours = (before_core + after_core) * (1 - idle_ratio)
        overtime_ratio = overtime_hours / active_hours if active_hours > 0 else 0

    active_minutes = active_hours * 60
    idle_minutes = active_minutes * random.uniform(0.10, 0.18)
    overtime_minutes = active_minutes * overtime_ratio

    first_h = int(start_hour)
    first_m = int((start_hour - first_h) * 60)
    end_h = int(end_hour)
    end_m = int((end_hour - end_h) * 60)

    first_activity = f"{first_h:02d}:{first_m:02d}:00"
    last_activity = f"{end_h:02d}:{end_m:02d}:00"

    category = "regular" if is_work_day else "overtime"

    # Generate app breakdown
    app_data = {}
    remaining = active_minutes
    core_minutes = active_minutes - overtime_minutes
    ot_minutes = overtime_minutes

    num_apps = random.randint(4, min(8, len(APPS)))
    for _ in range(num_apps + 3):  # extra iterations to distribute
        if remaining <= 1:
            break
        is_ot_chunk = random.random() < overtime_ratio
        chunk = random.uniform(8, max(10, remaining * 0.35))
        chunk = min(chunk, remaining)

        app_name = weighted_choice(APPS, is_ot_chunk)
        if app_name not in app_data:
            app_data[app_name] = {"total": 0, "regular": 0, "overtime": 0}

        app_data[app_name]["total"] += chunk
        if is_ot_chunk or is_weekend or weekday == 4:
            app_data[app_name]["overtime"] += chunk
        else:
            app_data[app_name]["regular"] += chunk
        remaining -= chunk

    # Distribute remaining to top app
    if remaining > 0 and app_data:
        top = max(app_data, key=lambda k: app_data[k]["total"])
        app_data[top]["total"] += remaining
        if is_weekend or weekday == 4:
            app_data[top]["overtime"] += remaining
        else:
            app_data[top]["regular"] += remaining

    return {
        "date": d.isoformat(),
        "day_of_week": weekday,
        "total_active_minutes": round(active_minutes, 1),
        "total_idle_minutes": round(idle_minutes, 1),
        "overtime_minutes": round(overtime_minutes, 1),
        "first_activity": first_activity,
        "last_activity": last_activity,
        "work_category": category,
        "apps": app_data,
    }


def main():
    random.seed(42)  # reproducible data

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Remove existing DB for clean seed
    if DB_PATH.exists():
        DB_PATH.unlink()
        for suffix in ["-wal", "-shm"]:
            p = DB_PATH.with_name(DB_PATH.name + suffix)
            if p.exists():
                p.unlink()

    conn = sqlite3.connect(str(DB_PATH))
    conn.executescript(SCHEMA_SQL)
    conn.execute("PRAGMA user_version = 1")

    # Seed settings
    conn.execute("INSERT INTO settings (id) VALUES (1)")

    # Generate 2 weeks: 2026-02-17 (Mo) to 2026-03-02 (Mo)
    start = date(2026, 2, 17)
    end = date(2026, 3, 2)
    current = start

    days_generated = 0
    while current <= end:
        day_data = generate_day(current)
        if day_data:
            conn.execute(
                """INSERT INTO daily_summary
                (date, day_of_week, total_active_minutes, total_idle_minutes,
                 overtime_minutes, first_activity, last_activity, work_category)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    day_data["date"], day_data["day_of_week"],
                    day_data["total_active_minutes"], day_data["total_idle_minutes"],
                    day_data["overtime_minutes"], day_data["first_activity"],
                    day_data["last_activity"], day_data["work_category"],
                ),
            )

            for app_name, data in day_data["apps"].items():
                conn.execute(
                    """INSERT INTO app_daily_summary
                    (date, app_name, active_minutes, regular_minutes, overtime_minutes)
                    VALUES (?, ?, ?, ?, ?)""",
                    (
                        day_data["date"], app_name,
                        round(data["total"], 1),
                        round(data["regular"], 1),
                        round(data["overtime"], 1),
                    ),
                )
            days_generated += 1

        current += timedelta(days=1)

    conn.commit()

    # Print summary
    total_days = conn.execute("SELECT COUNT(*) FROM daily_summary").fetchone()[0]
    total_apps = conn.execute("SELECT COUNT(*) FROM app_daily_summary").fetchone()[0]
    total_ot = conn.execute("SELECT SUM(overtime_minutes) FROM daily_summary").fetchone()[0]
    unique_apps = conn.execute("SELECT COUNT(DISTINCT app_name) FROM app_daily_summary").fetchone()[0]

    print(f"Seed DB created at {DB_PATH}")
    print(f"  {total_days} days of data ({start} to {end})")
    print(f"  {total_apps} app summary rows ({unique_apps} unique apps)")
    print(f"  {total_ot / 60:.1f}h total overtime")

    # Show per-day breakdown
    print("\nPer-day breakdown:")
    rows = conn.execute(
        "SELECT date, day_of_week, total_active_minutes, overtime_minutes, work_category "
        "FROM daily_summary ORDER BY date"
    ).fetchall()
    day_names = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    for r in rows:
        dn = day_names[r[1]] if 0 <= r[1] <= 6 else "?"
        print(f"  {r[0]} ({dn}): {r[2]:.0f}min aktiv, {r[3]:.0f}min OT [{r[4]}]")

    conn.close()


if __name__ == "__main__":
    main()

import sqlite3
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class WorkSchedule:
    """Defines core working hours and categories."""
    work_days: list[int] = field(default_factory=lambda: [0, 1, 2, 3])  # Mon-Thu
    core_start_hour: int = 9   # 09:00
    core_start_minute: int = 0
    core_end_hour: int = 18    # 18:00
    core_end_minute: int = 0
    weekly_target_hours: int = 32


@dataclass
class Config:
    """Application configuration with sensible defaults."""
    # Tracking
    polling_interval_seconds: int = 15
    idle_timeout_seconds: int = 600  # 10 minutes

    # Database
    db_path: Path = field(
        default_factory=lambda: Path.home() / ".overtime-tracker" / "overtime.db"
    )

    # Dashboard
    dashboard_port: int = 8080

    # Work schedule
    schedule: WorkSchedule = field(default_factory=WorkSchedule)

    def is_core_hours(self, weekday: int, hour: int, minute: int = 0) -> bool:
        """Check if a given weekday (0=Mon) and time falls within core working hours."""
        if weekday not in self.schedule.work_days:
            return False
        current = hour * 60 + minute
        start = self.schedule.core_start_hour * 60 + self.schedule.core_start_minute
        end = self.schedule.core_end_hour * 60 + self.schedule.core_end_minute
        return start <= current < end

    def get_work_category(self, weekday: int, hour: int) -> str:
        """Determine work category: 'regular' or 'overtime'."""
        if self.is_core_hours(weekday, hour):
            return "regular"
        return "overtime"

    def reload_from_db(self, db_path: Path | None = None):
        """Load settings from the SQLite settings table, falling back to defaults."""
        path = db_path or self.db_path
        if not path.exists():
            return
        try:
            conn = sqlite3.connect(str(path))
            conn.row_factory = sqlite3.Row
            row = conn.execute("SELECT * FROM settings WHERE id = 1").fetchone()
            conn.close()
        except (sqlite3.OperationalError, sqlite3.DatabaseError):
            return  # Table doesn't exist yet or DB corrupt — use defaults
        if row is None:
            return
        self.schedule.core_start_hour = row["core_start_hour"]
        self.schedule.core_end_hour = row["core_end_hour"]
        try:
            self.schedule.work_days = [int(d) for d in row["work_days"].split(",") if d.strip()]
        except (ValueError, TypeError):
            pass  # Keep defaults on malformed data
        self.idle_timeout_seconds = row["idle_timeout_seconds"]
        # Minute columns added in migration v2 — may not exist on older DBs
        try:
            self.schedule.core_start_minute = row["core_start_minute"]
            self.schedule.core_end_minute = row["core_end_minute"]
        except (IndexError, KeyError):
            pass


# Singleton config instance
config = Config()

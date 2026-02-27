from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class WorkSchedule:
    """Defines core working hours and categories."""
    work_days: list[int] = field(default_factory=lambda: [0, 1, 2, 3])  # Mon-Thu
    friday: int = 4
    core_start_hour: int = 9   # 09:00
    core_end_hour: int = 18    # 18:00
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

    def is_core_hours(self, weekday: int, hour: int) -> bool:
        """Check if a given weekday (0=Mon) and hour falls within core working hours."""
        if weekday not in self.schedule.work_days:
            return False
        return self.schedule.core_start_hour <= hour < self.schedule.core_end_hour

    def get_work_category(self, weekday: int, hour: int) -> str:
        """Determine work category: 'regular', 'overtime', or 'friday'."""
        if weekday == self.schedule.friday:
            return "friday"
        if weekday >= 5:  # Saturday/Sunday
            return "overtime"
        if self.is_core_hours(weekday, hour):
            return "regular"
        return "overtime"


# Singleton config instance
config = Config()

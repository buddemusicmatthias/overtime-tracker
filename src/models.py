from dataclasses import dataclass
from datetime import datetime


@dataclass
class ActivityRecord:
    """A single polling snapshot of user activity."""
    timestamp: datetime
    app_name: str
    bundle_id: str | None
    is_idle: bool
    idle_seconds: float
    poll_interval: int = 15


@dataclass
class DailySummary:
    """Aggregated activity data for a single day."""
    date: str                    # YYYY-MM-DD
    day_of_week: int             # 0=Mon ... 6=Sun
    total_active_minutes: float
    total_idle_minutes: float
    overtime_minutes: float
    first_activity: str | None   # HH:MM:SS
    last_activity: str | None    # HH:MM:SS
    work_category: str           # regular/overtime


@dataclass
class AppSummary:
    """Per-app activity breakdown for a single day."""
    date: str
    app_name: str
    active_minutes: float
    regular_minutes: float = 0.0
    overtime_minutes: float = 0.0

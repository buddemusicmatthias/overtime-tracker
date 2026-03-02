"""Activity tracker: polls active app and idle status on macOS."""

from datetime import datetime

from AppKit import NSWorkspace
from Quartz.CoreGraphics import (
    CGEventSourceSecondsSinceLastEventType,
    kCGEventSourceStateCombinedSessionState,
    kCGAnyInputEventType,
)

from src.config import config
from src.models import ActivityRecord
from src.database import log_activity, update_daily_summaries


def get_active_app() -> tuple[str, str | None]:
    """Return (app_name, bundle_id) of the frontmost application."""
    app = NSWorkspace.sharedWorkspace().frontmostApplication()
    if app:
        return app.localizedName() or "Unknown", app.bundleIdentifier()
    return "Unknown", None


def get_idle_seconds() -> float:
    """Return seconds since last keyboard/mouse/trackpad input."""
    return CGEventSourceSecondsSinceLastEventType(
        kCGEventSourceStateCombinedSessionState,
        kCGAnyInputEventType,
    )


def poll_and_log():
    """Single polling cycle: check active app + idle, log to database."""
    app_name, bundle_id = get_active_app()
    idle_secs = get_idle_seconds()
    is_idle = idle_secs >= config.idle_timeout_seconds

    record = ActivityRecord(
        timestamp=datetime.now(),
        app_name=app_name,
        bundle_id=bundle_id,
        is_idle=is_idle,
        idle_seconds=idle_secs,
        poll_interval=config.polling_interval_seconds,
    )

    log_activity(record)

    # Update daily summaries every 20 polls (~5 minutes at 15s interval)
    if not hasattr(poll_and_log, "_counter"):
        poll_and_log._counter = 0
    poll_and_log._counter += 1
    if poll_and_log._counter >= 20:
        poll_and_log._counter = 0
        update_daily_summaries()
        config.reload_from_db()

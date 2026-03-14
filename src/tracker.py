"""Activity tracker: polls active app and idle status on macOS."""

import sys
from datetime import datetime

from AppKit import NSWorkspace
from Quartz.CoreGraphics import (
    CGEventSourceSecondsSinceLastEventType,
    CGWindowListCopyWindowInfo,
    kCGEventSourceStateCombinedSessionState,
    kCGAnyInputEventType,
    kCGWindowListOptionOnScreenOnly,
    kCGWindowListExcludeDesktopElements,
    kCGNullWindowID,
)

from src.config import config
from src.models import ActivityRecord
from src.database import log_activity, update_daily_summaries


def _find_topmost_window_owner() -> tuple[str, str | None] | None:
    """Find the owner of the topmost normal (layer 0) window via CGWindowList.

    Returns (app_name, bundle_id) or None if no suitable window is found.
    """
    windows = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID,
    )
    if not windows:
        return None

    for w in windows:
        # Layer 0 = normal application windows (skip menubar, overlays, etc.)
        if w.get("kCGWindowLayer", -1) != 0:
            continue
        pid = w.get("kCGWindowOwnerPID")
        owner_name = w.get("kCGWindowOwnerName", "Unknown")
        # Match PID to running apps to get the bundle ID
        for app in NSWorkspace.sharedWorkspace().runningApplications():
            if app.processIdentifier() == pid:
                return app.localizedName() or owner_name, app.bundleIdentifier()
        return owner_name, None

    return None


def get_active_app() -> tuple[str, str | None]:
    """Return (app_name, bundle_id) of the application the user is working in.

    Primary source: NSWorkspace.frontmostApplication().
    Validation: checks whether that app owns a visible window (layer 0).
    If not (e.g. a VPN client with only a menubar icon), falls back to the
    owner of the topmost visible window via CGWindowListCopyWindowInfo.
    """
    app = NSWorkspace.sharedWorkspace().frontmostApplication()
    if not app:
        return _find_topmost_window_owner() or ("Unknown", None)

    frontmost_name = app.localizedName() or "Unknown"
    frontmost_bundle = app.bundleIdentifier()
    frontmost_pid = app.processIdentifier()

    # Validate: does the frontmost app actually own a visible standard window?
    windows = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID,
    )
    if not windows:
        return frontmost_name, frontmost_bundle

    has_visible_window = any(
        w.get("kCGWindowOwnerPID") == frontmost_pid
        and w.get("kCGWindowLayer", -1) == 0
        for w in windows
    )

    if has_visible_window:
        return frontmost_name, frontmost_bundle

    # Frontmost app has no normal window — fall back to topmost window owner
    fallback = _find_topmost_window_owner()
    if fallback:
        print(
            f"[tracker] frontmost '{frontmost_name}' has no visible window, "
            f"using '{fallback[0]}' instead",
            file=sys.stderr,
        )
        return fallback

    return frontmost_name, frontmost_bundle


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
    update_daily_summaries()
    config.reload_from_db()

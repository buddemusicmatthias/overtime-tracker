# Overtime Tracker

## Project Overview
macOS menubar app that tracks overtime hours automatically. Two components: a Python daemon that detects active apps and idle time, and a native SwiftUI app with menubar popover, dashboard, and settings.

## Tech Stack
- **Python daemon:** Python 3.13+, pyobjc-framework-Cocoa, pyobjc-framework-Quartz
- **SwiftUI app:** Swift 5, GRDB.swift (SQLite), Swift Charts, macOS 26.2+
- **Shared:** SQLite with WAL mode at `~/.overtime-tracker/overtime.db`

## Architecture
- **Python daemon** (`src/`): Headless process, polls active app every 15s, detects idle via CGEventSource, writes to SQLite. Runs as LaunchAgent.
- **SwiftUI app** (`OvertimeTracker/`): Reads same SQLite DB. Menubar icon + NSPopover, Dashboard window (4 tabs), Settings window. Manages LaunchAgent install via `LaunchAgentManager`.
- WAL mode allows concurrent writes (Python) + reads (Swift).

## Running

```bash
# Python daemon (manual)
python3 -m venv venv
venv/bin/pip install -r requirements.txt
venv/bin/python -m src.main

# SwiftUI app
# Open OvertimeTracker/OvertimeTracker.xcodeproj in Xcode → Run

# LaunchAgent (managed by Swift app's "Launch at Login" toggle)
launchctl list | grep overtime                # Status
tail -f /tmp/overtime-tracker.stderr.log      # Daemon logs
```

## Conventions
- Python source: `src/`
- Swift source: `OvertimeTracker/OvertimeTracker/`
- Tests: `tests/`
- Test data: `scripts/seed_testdata.py`
- Python entry point: `src/main.py`
- Swift entry point: `OvertimeTrackerApp.swift`

## Key Parameters (configurable in Settings)
- Work categories: `regular` and `overtime` only
- Core hours: Default Mon–Thu, 09:00–18:00 (configurable per-day, 15-min granularity)
- Idle timeout: Default 10 minutes (configurable)
- Polling interval: 15 seconds

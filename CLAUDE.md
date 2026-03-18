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
tail -f ~/.overtime-tracker/daemon.stderr.log  # Daemon logs
```

## Conventions
- Python source: `src/`
- Swift source: `OvertimeTracker/OvertimeTracker/`
- Test data: `scripts/seed_testdata.py`
- Python entry point: `src/main.py`
- Swift entry point: `OvertimeTrackerApp.swift`

## Key Parameters (configurable in Settings)
- Work categories: `regular` and `overtime` only
- Core hours: Default Mon–Thu, 09:00–18:00 (configurable per-day, 15-min granularity)
- Idle timeout: Default 10 minutes (configurable)
- Polling interval: 15 seconds

## TODOs
- Monitor CPU/energy usage with `update_daily_summaries()` running every 15s poll cycle (was previously batched to every ~5 min). If it causes noticeable CPU or battery drain, reintroduce batching (e.g. every 4 polls = ~1 min).

## Distribution (internal)

To build a distributable zip for others (no Xcode needed on their end):

1. Xcode → Product → Archive → Distribute App → "Copy App" → choose folder
2. Bundle into a zip:
   ```
   OvertimeTracker/
   ├── OvertimeTracker.app   ← from Archive export
   ├── setup.sh              ← from repo root
   ├── src/                  ← Python daemon (whole folder)
   └── requirements.txt      ← from repo root
   ```
3. Recipient runs: `chmod +x setup.sh && ./setup.sh`, then opens the app (right-click → Open the first time for Gatekeeper)

### Updating the daemon on a remote machine (no Xcode needed)

When only `src/` has changed (no Swift changes), the .app doesn't need to be rebuilt:

1. Copy the updated `src/` folder to the machine (replace existing)
2. Restart the daemon: toggle "Launch at Login" off/on in Settings, or:
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.overtime-tracker.daemon
   ```
3. Verify via `tail -f /tmp/overtime-tracker.stderr.log`

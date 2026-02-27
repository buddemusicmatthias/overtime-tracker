# Overtime Tracker

## Project Overview
macOS menubar app that tracks overtime hours automatically. Detects active app, idle time, and categorizes work into regular hours, overtime, and Friday buffer.

## Tech Stack
- Python 3.13+ with `python3 -m venv` (NOT virtualenv — rumps incompatible)
- rumps: macOS menubar framework
- pyobjc-framework-Cocoa + pyobjc-framework-Quartz: macOS APIs
- NiceGUI: Dashboard (runs as separate subprocess)
- SQLite with WAL mode: Local data storage at ~/.overtime-tracker/overtime.db

## Architecture
- Main process: rumps app (menubar + tracker polling)
- Subprocess: NiceGUI dashboard (launched on demand, port 8080)
- Both share SQLite DB via WAL mode for concurrent read/write

## Running the App

```bash
# 1. Setup (einmalig)
python3 -m venv venv
venv/bin/pip install -r requirements.txt

# 2a. Manuell starten (aus Projekt-Root)
venv/bin/python -m src.main

# 2b. Als LaunchAgent installieren (Autostart beim Login)
./scripts/install.sh

# LaunchAgent verwalten
launchctl list | grep overtime          # Status prüfen
launchctl unload ~/Library/LaunchAgents/com.matthias.overtime-tracker.plist  # Stoppen
tail -f /tmp/overtime-tracker.stderr.log  # Logs ansehen
```

## Conventions
- Dependencies: requirements.txt
- Source code: src/
- Tests: tests/
- Entry point: src/main.py

## Key Parameters
- Core hours: Mon-Thu, 09:00-18:00
- Weekly target: 32h
- Idle timeout: 10 minutes
- Polling interval: 15 seconds
- Friday: logged separately (not auto-categorized)

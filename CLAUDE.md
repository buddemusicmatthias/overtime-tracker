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

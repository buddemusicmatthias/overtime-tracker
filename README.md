# Overtime Tracker

A macOS menubar app that automatically tracks overtime. You define your regular work hours — anything beyond counts as overtime. A Python daemon detects the active app and idle time in the background, a native SwiftUI app shows live stats in the menubar and provides a dashboard with charts and CSV export.

All data stays local in a SQLite database. Nothing is sent anywhere.

## Features

- **Menubar** — live overtime counter (e.g. `1:07 OT`), click for today's stats and weekly bar chart
- **Dashboard** — Today / Week / Month / Export tabs with app breakdowns and charts
- **Settings** — core hours, work days, idle timeout, launch at login, dock visibility
- **CSV Export** — date range picker with preview

## Installation

> **Important:** Clone the repo to its permanent location first. The Swift app bakes in the path to the Python daemon at compile time — moving the repo afterwards breaks the connection.

```bash
# 1. Clone
git clone https://github.com/buddemusicmatthias/overtime-tracker.git
cd overtime-tracker

# 2. Python daemon setup
python3 -m venv venv
venv/bin/pip install -r requirements.txt

# 3. Build the Swift app
open OvertimeTracker/OvertimeTracker.xcodeproj
# In Xcode: Product → Run (⌘R)
```

The app appears in the menubar as `0:00 OT`. Open Settings (gear icon in the popover) and enable **Launch at Login** — this auto-starts both the daemon and the app on every login.

## Requirements

- macOS 15+
- Python 3.13+
- Xcode 16+

## License

MIT

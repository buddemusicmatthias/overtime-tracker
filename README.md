# Overtime Tracker

A macOS menubar app that passively tracks your overtime. Define your regular work hours — everything beyond is overtime. No timers to start, no buttons to press.

A Python daemon detects the active app and idle time in the background. A native SwiftUI app shows live stats in the menubar and provides a dashboard with charts and CSV export. All data stays local in a SQLite database.

## Why

I am lazy and forgetful but somehow I still work too many hours. I catch up on focused technical work on days off — a bit here, a bit there — and it adds up. I've started overtime spreadsheets more times than I can count, but even slight friction makes me drop a habit after two attempts. The hours just disappear.

So I built something with zero ongoing effort: set your core hours once, then forget about it. The app runs silently, logs which apps you use during overtime (turns out it's mostly Terminal and PyCharm, not Slack), and gives you charts and CSV exports for salary negotiations.

No subscription, no manual input, no cloud. If you're like me, maybe this thing can recoup all the money spent on AI subscriptions...

## Features

- **Menubar** — live overtime counter (e.g. `1:07 OT`), click for today's stats and a weekly bar chart
- **Dashboard** — Today / Week / Month / Export tabs with per-app breakdowns and charts
- **Settings** — core hours per weekday, idle timeout, launch at login, dock visibility
- **CSV Export** — date range picker with preview

<!-- TODO: Add screenshot
![Menubar and Dashboard](screenshot.png)
-->

## Architecture

```
Python daemon (src/)            SwiftUI app (OvertimeTracker/)
Polls active app every 15s      Reads DB, shows menubar stats
Detects idle time               Dashboard with charts
Writes to SQLite ────────────── Reads from SQLite (WAL mode)
            └── ~/.overtime-tracker/overtime.db
```

Both run in parallel. SQLite WAL mode allows concurrent writes and reads.

## Requirements

- macOS 15+
- Python 3.13+
- Xcode 16+ (to build the Swift app)

## Setup

```bash
git clone https://github.com/buddemusicmatthias/overtime-tracker.git
cd overtime-tracker

# Set up Python daemon
./setup.sh

# Build and run the Swift app
open OvertimeTracker/OvertimeTracker.xcodeproj
# Product → Run (⌘R)
```

After launching, click the menubar icon → Settings → enable "Launch at Login" to start the daemon automatically.

## License

MIT

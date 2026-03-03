"""macOS menubar app for overtime tracking using rumps."""

import sys
from datetime import date, datetime

import rumps

from src.config import config
from src.tracker import poll_and_log
from src.database import get_daily_summary, get_week_summaries, update_daily_summaries


class OvertimeTrackerApp(rumps.App):
    def __init__(self):
        super().__init__(
            "OT",
            title="0:00 OT",
            quit_button=None,  # we add our own quit button
        )
        self.tracking_active = True

        self.menu = [
            rumps.MenuItem("today_label", callback=None),
            rumps.MenuItem("week_label", callback=None),
            None,  # separator
            rumps.MenuItem("Pause Tracking", callback=self.toggle_tracking),
            None,
            rumps.MenuItem("Quit", callback=self.quit_app),
        ]
        self._update_menu_labels()

    @rumps.timer(config.polling_interval_seconds)
    def on_tick(self, _):
        """Runs every polling interval — tracks activity and updates menu."""
        if not self.tracking_active:
            return
        try:
            poll_and_log()
        except Exception as e:
            print(f"Tracking error: {e}", file=sys.stderr)
        self._update_menu_labels()

    def _update_menu_labels(self):
        """Refresh the menu items with current data."""
        today_str = date.today().isoformat()
        summary = get_daily_summary(today_str)

        if summary:
            active_h = int(summary.total_active_minutes // 60)
            active_m = int(summary.total_active_minutes % 60)
            ot_h = int(summary.overtime_minutes // 60)
            ot_m = int(summary.overtime_minutes % 60)
            self.title = f"{ot_h}:{ot_m:02d} OT"
            self.menu["today_label"].title = (
                f"Today: {active_h}h {active_m}m active | {ot_h}h {ot_m}m overtime"
            )
        else:
            self.title = "0:00 OT"
            self.menu["today_label"].title = "Today: no data yet"

        # Week summary
        now = datetime.now()
        iso_year, iso_week, _ = now.isocalendar()
        week_data = get_week_summaries(iso_year, iso_week)
        if week_data:
            week_ot = sum(d.overtime_minutes for d in week_data)
            week_active = sum(d.total_active_minutes for d in week_data)
            wot_h = int(week_ot // 60)
            wot_m = int(week_ot % 60)
            wa_h = int(week_active // 60)
            wa_m = int(week_active % 60)
            self.menu["week_label"].title = (
                f"Week: {wa_h}h {wa_m}m active | {wot_h}h {wot_m}m overtime"
            )
        else:
            self.menu["week_label"].title = "Week: no data yet"

    def toggle_tracking(self, sender):
        """Pause or resume activity tracking."""
        self.tracking_active = not self.tracking_active
        sender.title = "Resume Tracking" if not self.tracking_active else "Pause Tracking"
        if not self.tracking_active:
            self.title = "PAUSED"
        else:
            self._update_menu_labels()

    def quit_app(self, _):
        """Clean shutdown: update summaries and quit."""
        update_daily_summaries()
        rumps.quit_application()

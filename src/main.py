"""Entry point for the Overtime Tracker menubar app."""

from src.database import init_db
from src.menubar import OvertimeTrackerApp


def main():
    init_db()
    app = OvertimeTrackerApp()
    app.run()


if __name__ == "__main__":
    main()

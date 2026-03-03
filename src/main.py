"""Entry point for the Overtime Tracker daemon (headless)."""

import signal
import sys
import time

from src.config import config
from src.database import init_db, update_daily_summaries
from src.tracker import poll_and_log


def main():
    init_db()

    running = True

    def handle_shutdown(signum, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, handle_shutdown)
    signal.signal(signal.SIGINT, handle_shutdown)

    print(f"Overtime Tracker daemon started (polling every {config.polling_interval_seconds}s)", file=sys.stderr)

    while running:
        try:
            poll_and_log()
        except Exception as e:
            print(f"Tracking error: {e}", file=sys.stderr)
        time.sleep(config.polling_interval_seconds)

    # Clean shutdown: final summary update
    print("Shutting down, writing final summary…", file=sys.stderr)
    update_daily_summaries()


if __name__ == "__main__":
    main()

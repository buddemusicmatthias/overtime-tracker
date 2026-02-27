#!/bin/bash
# Install Overtime Tracker as a macOS LaunchAgent (autostart on login)

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_SRC="$PROJECT_DIR/com.matthias.overtime-tracker.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.matthias.overtime-tracker.plist"
VENV_DIR="$PROJECT_DIR/venv"

echo "=== Overtime Tracker Installer ==="
echo ""

# 1. Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# 2. Install dependencies
echo "Installing dependencies..."
"$VENV_DIR/bin/pip" install -q -r "$PROJECT_DIR/requirements.txt"

# 3. Get the Python path from the venv
PYTHON_PATH="$VENV_DIR/bin/python"

# 4. Generate plist with correct paths
echo "Generating LaunchAgent plist..."
sed -e "s|__PYTHON_PATH__|$PYTHON_PATH|g" \
    -e "s|__PROJECT_DIR__|$PROJECT_DIR|g" \
    "$PLIST_SRC" > "$PLIST_DST"
chmod 644 "$PLIST_DST"

# 5. Unload old version if running
launchctl unload "$PLIST_DST" 2>/dev/null || true

# 6. Load the LaunchAgent
echo "Loading LaunchAgent..."
launchctl load "$PLIST_DST"

echo ""
echo "Done! Overtime Tracker is now running and will start automatically on login."
echo ""
echo "Useful commands:"
echo "  Check status:  launchctl list | grep overtime"
echo "  View logs:     tail -f /tmp/overtime-tracker.stderr.log"
echo "  Stop:          launchctl unload $PLIST_DST"
echo "  Restart:       launchctl unload $PLIST_DST && launchctl load $PLIST_DST"

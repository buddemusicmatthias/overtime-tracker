#!/bin/bash
# Overtime Tracker — Setup
# Erstellt venv und kopiert Python-Daemon nach ~/.overtime-tracker/

set -e

OT_DIR="$HOME/.overtime-tracker"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$OT_DIR"

echo "→ Erstelle Python-venv..."
python3 -m venv "$OT_DIR/venv"

echo "→ Installiere Abhängigkeiten..."
"$OT_DIR/venv/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt"

echo "→ Kopiere Daemon-Source..."
rm -rf "$OT_DIR/src"
cp -R "$SCRIPT_DIR/src" "$OT_DIR/src"
cp "$SCRIPT_DIR/requirements.txt" "$OT_DIR/requirements.txt"

echo "✓ Setup abgeschlossen. Starte OvertimeTracker.app und aktiviere 'Beim Login starten'."

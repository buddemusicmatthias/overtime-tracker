# Overtime Tracker

A macOS menubar app that automatically tracks overtime. You define your regular work hours — anything beyond counts as overtime. A Python daemon detects the active app and idle time in the background, a native SwiftUI app shows live stats in the menubar and provides a dashboard with charts and CSV export.

All data stays local in a SQLite database. Nothing is sent anywhere.

## Features

- **Menubar** — live overtime counter (e.g. `1:07 OT`), click for today's stats and weekly bar chart
- **Dashboard** — Today / Week / Month / Export tabs with app breakdowns and charts
- **Settings** — core hours, work days, idle timeout, launch at login, dock visibility
- **CSV Export** — date range picker with preview

## Installation (fertige App erhalten)

Du hast einen Zip-Ordner mit der fertigen App bekommen? Dann brauchst du kein Xcode — nur Python 3.

### Voraussetzungen

- macOS 15+
- Python 3 (prüfen mit `python3 --version`)

### Schritte

```bash
# 1. Zip entpacken und Terminal im entpackten Ordner öffnen

# 2. Setup ausführen (erstellt Python-Umgebung unter ~/.overtime-tracker/)
chmod +x setup.sh
./setup.sh

# 3. App verschieben (optional, geht auch von woanders)
cp -R OvertimeTracker.app /Applications/
```

4. **App starten:** Rechtsklick auf `OvertimeTracker.app` → **Öffnen** (beim ersten Mal nötig wegen Gatekeeper, danach normal per Doppelklick)
5. **Daemon aktivieren:** Im Popover das Zahnrad-Icon klicken → **Beim Login starten** einschalten

Fertig. Die App erscheint in der Menubar als `0:00 OT` und der Daemon läuft im Hintergrund.

## Distribution (App für andere bauen)

Du willst die App an Kollegen verteilen? So erstellst du das Zip-Paket:

### 1. App in Xcode archivieren

```
Xcode → Product → Archive → Distribute App → "Copy App" → Zielordner wählen
```

### 2. Zip-Paket zusammenstellen

Erstelle einen Ordner mit diesen Dateien:

```
OvertimeTracker/
├── OvertimeTracker.app   ← aus Schritt 1
├── setup.sh              ← aus dem Repo-Root
├── src/                  ← Python-Daemon (ganzer Ordner)
└── requirements.txt      ← aus dem Repo-Root
```

```bash
# Beispiel (nach Archive-Export nach ~/Desktop/export/):
mkdir -p ~/Desktop/OvertimeTracker
cp -R ~/Desktop/export/OvertimeTracker.app ~/Desktop/OvertimeTracker/
cp setup.sh ~/Desktop/OvertimeTracker/
cp -R src ~/Desktop/OvertimeTracker/
cp requirements.txt ~/Desktop/OvertimeTracker/

# Zip erstellen
cd ~/Desktop
zip -r OvertimeTracker.zip OvertimeTracker/
```

### 3. Zip verschicken

Die Datei `OvertimeTracker.zip` an Kollegen schicken. Sie brauchen nur Python 3 — kein Xcode, kein Klonen.

## Entwicklung

Für Entwickler, die am Code arbeiten wollen:

### Voraussetzungen

- macOS 15+
- Python 3.13+
- Xcode 16+

### Setup

```bash
git clone https://github.com/buddemusicmatthias/overtime-tracker.git
cd overtime-tracker

# Python-Daemon einrichten
./setup.sh

# Swift-App in Xcode öffnen
open OvertimeTracker/OvertimeTracker.xcodeproj
# Product → Run (⌘R)
```

## Architektur

```
~/.overtime-tracker/          ← Runtime-Verzeichnis
├── overtime.db               ← SQLite-Datenbank (WAL mode)
├── venv/                     ← Python virtual environment
├── src/                      ← Python-Daemon
└── requirements.txt

OvertimeTracker.app           ← SwiftUI Menubar-App (liest DB)
```

- **Python-Daemon** schreibt alle 15s die aktive App und Idle-Zeit in die DB
- **SwiftUI-App** liest die gleiche DB und zeigt Live-Stats in der Menubar
- Beide laufen parallel, WAL mode ermöglicht gleichzeitiges Lesen und Schreiben

## License

MIT

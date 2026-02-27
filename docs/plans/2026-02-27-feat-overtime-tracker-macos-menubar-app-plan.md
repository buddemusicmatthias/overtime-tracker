---
title: "feat: Overtime Tracker macOS Menubar App"
type: feat
status: completed
date: 2026-02-27
origin: docs/brainstorms/2026-02-27-overtime-tracker-brainstorm.md
---

# feat: Overtime Tracker macOS Menubar App

## Overview

Eine macOS-Menüleisten-App, die automatisch Überstunden erfasst — mit aktiver App-Erkennung, Idle-Detection (10 Min Timeout) und Kategorisierung in reguläre Arbeitszeit, Überstunden und Freitags-Arbeit. Ziel: belastbare Zahlen für Gehaltsverhandlungen.

(see brainstorm: docs/brainstorms/2026-02-27-overtime-tracker-brainstorm.md)

## Problem Statement / Motivation

Matthias arbeitet als Teamlead regelmäßig unbezahlte Überstunden, um tech-fokussierte Arbeit außerhalb der meeting-lastigen Kernzeit zu erledigen. Es fehlen belegbare Daten, um dies in Gehaltsverhandlungen zu adressieren. Manuelles Tracking ist unzuverlässig — die App soll automatisch und passiv im Hintergrund laufen.

## Proposed Solution

Python-basierte Menüleisten-App mit drei Komponenten:

1. **Tracker (rumps + pyobjc):** Pollt alle 15s die aktive App + Idle-Status, loggt in SQLite
2. **Menüleisten-UI (rumps):** Quick-Übersicht im Dropdown (Tages-/Wochensummary)
3. **Dashboard (NiceGUI):** Separater Prozess, lokaler Webserver mit Charts + CSV-Export

### Architektur

```
Main Process (rumps)              Subprocess (NiceGUI)
========================         =======================
- rumps.App.run()                - ui.run(port=8080)
- @rumps.timer(15) polls:        - Liest aus SQLite (WAL)
    - NSWorkspace -> App-Name    - Rendert Dashboard
    - CGEventSource -> Idle      - Charts, Filter, Export
    - Schreibt in SQLite
- Menü zeigt Tagessummary
- "Open Dashboard" Button
    -> startet Subprocess
    -> öffnet Browser

LaunchAgent (Autostart)
========================
- Startet Main Process beim Login
- KeepAlive=true für Crash Recovery
```

**Warum separate Prozesse:** rumps und NiceGUI blockieren beide den Main-Thread. Threading ist fragil (NiceGUI warnt explizit davor). Subprocess-Ansatz ist robust — SQLite WAL-Modus handhabt concurrent reads/writes.

## Technical Considerations

### macOS-APIs (kein spezieller Permission-Aufwand)

- **Aktive App:** `NSWorkspace.sharedWorkspace().frontmostApplication()` — keine Permissions nötig
- **Idle-Detection:** `CGEventSourceSecondsSinceLastEventType()` — keine Permissions nötig
- **Window-Titel:** `CGWindowListCopyWindowInfo()` — braucht Screen Recording Permission. **Für MVP nicht nötig**, App-Name reicht.

### Bekannte Gotchas

- **rumps + virtualenv:** `virtualenv` kopiert den Python-Interpreter und verursacht Probleme. Stattdessen `python3 -m venv` nutzen (erstellt Symlinks).
- **rumps auf Sonoma/Sequoia:** `rumps.Window`-Dialoge haben Fokus-Probleme (Issue #225). Betrifft uns nicht — wir nutzen nur Menü-Dropdown + Browser-Dashboard.
- **rumps + Python 3.12+:** Nur beim Bundling mit py2app problematisch (`imp` Modul entfernt). LaunchAgent-Ansatz (direkt `python main.py`) funktioniert einwandfrei.
- **NiceGUI Threading:** `reload=True` (Default!) nutzt watchdog-File-Monitoring, das mit rumps kollidiert. Immer `ui.run(reload=False, show=False)`.

### Projekt-Setup

- **Dependency Management:** `requirements.txt` + `python3 -m venv` (konsistent mit bestehenden Projekten)
- **Python:** 3.13.5 (via miniconda3, bereits installiert)
- **DB-Pfad:** `~/.overtime-tracker/overtime.db` (im Home-Verzeichnis, nicht im Repo)

## SQLite Schema

```sql
PRAGMA journal_mode=WAL;

-- Kern-Tabelle: eine Zeile pro Polling-Intervall
CREATE TABLE activity_log (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now','localtime')),
    app_name       TEXT NOT NULL,
    bundle_id      TEXT,
    is_idle        INTEGER NOT NULL DEFAULT 0,
    idle_seconds   REAL,
    poll_interval  INTEGER NOT NULL DEFAULT 15
);

-- Tägliche Zusammenfassung (vom Tracker periodisch aktualisiert)
CREATE TABLE daily_summary (
    date                  TEXT PRIMARY KEY,
    day_of_week           INTEGER NOT NULL,  -- 0=Mo ... 6=So
    total_active_minutes  REAL NOT NULL DEFAULT 0,
    total_idle_minutes    REAL NOT NULL DEFAULT 0,
    overtime_minutes      REAL NOT NULL DEFAULT 0,
    first_activity        TEXT,
    last_activity         TEXT,
    work_category         TEXT NOT NULL DEFAULT 'regular'  -- regular/overtime/friday
);

-- App-Aufschlüsselung pro Tag
CREATE TABLE app_daily_summary (
    date           TEXT NOT NULL,
    app_name       TEXT NOT NULL,
    active_minutes REAL NOT NULL DEFAULT 0,
    PRIMARY KEY (date, app_name)
);

CREATE INDEX idx_activity_timestamp ON activity_log(timestamp);
CREATE INDEX idx_activity_date ON activity_log(date(timestamp));
```

**Design-Entscheidungen:**
- `poll_interval` als Spalte → Intervall-Änderungen invalidieren keine historischen Daten
- `idle_seconds` roh speichern → Idle-Threshold nachträglich anpassbar
- Summary-Tabellen → Dashboard muss nicht über Millionen Roh-Zeilen aggregieren
- WAL-Modus → Concurrent reads (Dashboard) + writes (Tracker)

## Arbeitszeitmodell

(see brainstorm: Resolved Questions)

| Parameter | Wert |
|-----------|------|
| Kernarbeitszeit | Mo-Do, 09:00-18:00 |
| Wochenstunden (Soll) | 32h |
| Idle-Timeout | 10 Minuten |
| Polling-Intervall | 15 Sekunden |
| Freitag | Separat loggen, kein Auto-Ausgleich |
| Sa/So | Overtime |
| Daten-Retention | Unbegrenzt |

**Overtime-Berechnung:**
- Aktivität Mo-Do vor 09:00 oder nach 18:00 → Overtime
- Aktivität Sa/So → Overtime
- Aktivität Fr → Kategorie "friday" (separat ausgewiesen)
- Idle-Perioden (>10 Min) werden nicht als Arbeitszeit gezählt

## Implementation Phases

### Phase 1: Projekt-Setup + Tracking-Core

**Ziel:** Tracking läuft im Hintergrund und loggt in SQLite.

**Dateien:**

```
overtime-tracker/
├── CLAUDE.md
├── .gitignore
├── requirements.txt
├── src/
│   ├── __init__.py
│   ├── config.py          # Kernarbeitszeiten, Idle-Threshold, DB-Pfad
│   ├── tracker.py         # Activity-Polling (NSWorkspace + CGEventSource)
│   ├── database.py        # SQLite-Verbindung, Schema-Init, Log-Funktionen
│   └── models.py          # Dataclasses für ActivityRecord, DailySummary
├── docs/
│   ├── brainstorms/
│   └── plans/
└── tests/
    └── test_tracker.py
```

**Aufgaben:**
- [x] `git init` im Projektverzeichnis (aktuell fehlerhaft auf Home-Dir-Ebene)
- [x] `.gitignore` erstellen (venv/, __pycache__/, *.db, .DS_Store)
- [x] `requirements.txt` mit: rumps, pyobjc-framework-Cocoa, pyobjc-framework-Quartz, nicegui
- [x] `src/config.py` — Konfiguration als Dataclass (Kernzeiten, Idle-Threshold, Polling-Intervall, DB-Pfad)
- [x] `src/database.py` — SQLite-Setup (WAL, Schema-Migration, CRUD-Funktionen)
- [x] `src/tracker.py` — Polling-Loop: aktive App + Idle-Status abfragen, in DB loggen
- [x] `src/models.py` — ActivityRecord, DailySummary als Dataclasses
- [x] Manueller Test: Script starten, 2-3 Minuten laufen lassen, DB inspizieren

### Phase 2: Menüleisten-App (rumps)

**Ziel:** App sitzt in der Menüleiste, zeigt Tagessummary, startet automatisch.

**Dateien:**

```
src/
├── main.py              # Entry-Point: rumps.App mit Timer-Callbacks
└── menubar.py           # OvertimeTrackerApp(rumps.App) Klasse
```

**Aufgaben:**
- [x] `src/menubar.py` — rumps.App-Klasse mit:
  - Menü-Items: "Heute: Xh Ym", "Woche: Xh Ym", Separator, "Open Dashboard", "Pause/Resume", Separator, "Quit"
  - `@rumps.timer(15)` → ruft Tracker auf, aktualisiert Menü-Text
  - `@rumps.clicked("Open Dashboard")` → startet Dashboard-Subprocess + öffnet Browser
  - `@rumps.clicked("Pause/Resume")` → Toggle für Tracking
- [x] `src/main.py` — Entry-Point, initialisiert DB, startet rumps.App
- [x] LaunchAgent-plist erstellen (`com.matthias.overtime-tracker.plist`)
- [x] Install-Script für LaunchAgent (`scripts/install.sh`)

### Phase 3: NiceGUI Dashboard

**Ziel:** Detaillierte Auswertung im Browser mit Charts und Export.

**Dateien:**

```
src/
└── dashboard.py         # NiceGUI-App (separater Prozess)
```

**Aufgaben:**
- [x] `src/dashboard.py` — NiceGUI-Dashboard mit:
  - **Tagesansicht:** Aktive Zeit, Overtime, Top-Apps (Balkendiagramm)
  - **Wochenansicht:** Überstunden pro Tag (Balkendiagramm), Soll/Ist-Vergleich
  - **Monatsansicht:** Kumulierte Überstunden, Trend-Linie
  - **App-Aufschlüsselung:** Welche Apps wann genutzt (Pie-Chart oder Tabelle)
  - **Filter:** Datums-Range, Wochentag, App-Name
  - **CSV-Export:** Button zum Herunterladen der Rohdaten
- [x] Summary-Berechnung: Aggregation der activity_log-Daten in daily_summary + app_daily_summary
- [x] Overtime-Berechnung: Aktivität außerhalb Kernzeit identifizieren und summieren

## Acceptance Criteria

- [ ] App startet automatisch beim Login (LaunchAgent)
- [ ] Menüleisten-Icon zeigt aktuelle Overtime des Tages
- [ ] Klick auf Icon zeigt Dropdown mit Tages- und Wochensummary
- [ ] "Open Dashboard" öffnet NiceGUI im Browser
- [ ] Dashboard zeigt Überstunden pro Tag/Woche/Monat mit Charts
- [ ] Dashboard zeigt App-Aufschlüsselung
- [ ] CSV-Export der Rohdaten funktioniert
- [ ] Idle-Perioden (>10 Min) werden korrekt erkannt und nicht als Arbeitszeit gezählt
- [ ] Freitags-Arbeit wird separat von Mo-Do-Overtime ausgewiesen
- [ ] Sa/So-Arbeit wird als Overtime gezählt
- [ ] App verbraucht minimal CPU/RAM im Hintergrund (<1% CPU, <50MB RAM)

## Success Metrics

- Überstunden sind auf Tages-/Wochen-/Monatsbasis quantifizierbar
- Daten sind als CSV exportierbar für Gehaltsverhandlungen
- App läuft zuverlässig über Wochen ohne manuelle Intervention
- Freitags-Ausgleich ist in den Daten sichtbar und von Overtime unterscheidbar

## Dependencies & Risks

| Risiko | Wahrscheinlichkeit | Mitigation |
|--------|---------------------|------------|
| rumps ist unmaintained (letztes Update 2022) | Mittel | macOS-APIs, die rumps nutzt, sind stabil. Falls nötig: Fork oder Wechsel zu `py-macmenubar` |
| macOS-Update bricht pyobjc-APIs | Niedrig | pyobjc wird aktiv maintained, APIs sind stabil seit Jahren |
| Hoher CPU-Verbrauch durch 15s-Polling | Niedrig | Polling ist sehr leichtgewichtig (1 API-Call pro Poll). Monitoring in Phase 2 |
| SQLite-DB wird zu groß | Niedrig | ~2MB/Monat bei 15s-Intervall. Selbst nach Jahren kein Problem |

## Sources & References

### Origin

- **Brainstorm document:** [docs/brainstorms/2026-02-27-overtime-tracker-brainstorm.md](docs/brainstorms/2026-02-27-overtime-tracker-brainstorm.md) — Entscheidungen: Tech-Stack (Python/rumps/NiceGUI), Idle-Timeout (10 Min), globale Kernzeit (9-18 Mo-Do), KISS für Freitag, unbegrenzte Retention

### Technische Referenzen

- [rumps GitHub](https://github.com/jaredks/rumps) — macOS menubar framework
- [pyobjc-framework-Quartz](https://pypi.org/project/pyobjc-framework-Quartz/) — Idle-Detection + Window-APIs
- [NiceGUI Docs](https://nicegui.io/documentation) — Dashboard-Framework
- [SQLite WAL Mode](https://www.sqlite.org/wal.html) — Concurrent read/write
- [macOS LaunchAgent](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html) — Autostart-Setup
- [rumps Issue #225](https://github.com/jaredks/rumps/issues/225) — Window-Fokus-Problem auf Sonoma (betrifft uns nicht)

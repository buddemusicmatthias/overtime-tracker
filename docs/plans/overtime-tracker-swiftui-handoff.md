# Overtime Tracker — SwiftUI Frontend: Übergabe-Dokument

**Datum:** 2026-03-02
**Kontext:** Übergabe von Mockup-Phase (claude.ai) an Implementierung (Claude Code)
**Repo:** https://github.com/buddemusicmatthias/overtime-tracker

---

## 1. Zusammenfassung

Der Overtime Tracker ist eine macOS-App, die automatisch Überstunden erfasst. Das Backend (Python: Tracker, SQLite-DB, Idle-Detection) existiert bereits und funktioniert. Dieses Dokument beschreibt die geplante **neue SwiftUI-Frontend-Implementierung**, die das bestehende NiceGUI-Browser-Dashboard und das rumps-Menüleisten-Dropdown ablösen soll.

**Was bleibt:** Python-Tracker als Hintergrund-Daemon, SQLite-Datenbank, LaunchAgent für Autostart.

**Was neu gebaut wird:** Native macOS-App in Swift/SwiftUI mit Menüleisten-Popover und Dashboard-Fenster.

---

## 2. Architektur-Entscheidung

### Gewählter Pfad: Swift/SwiftUI

Alternativen wurden evaluiert (PyWebView, Tauri, CustomTkinter, Status quo NiceGUI). SwiftUI wurde gewählt wegen:

- Echtes NSPopover aus der Menüleiste (nicht möglich mit PyWebView)
- Native macOS-Look and Feel
- Langfristig das sauberste Ergebnis
- Claude Code kann Swift/SwiftUI zuverlässig generieren

### Architektur-Überblick

```
Python-Daemon (bestehend)          SwiftUI-App (neu)
============================       ============================
- Pollt alle 15s aktive App        - Liest SQLite-DB (read-only)
- Erkennt Idle via CGEventSource   - Menüleisten-Icon + Popover
- Schreibt in SQLite (WAL)         - Dashboard-Fenster
- Läuft als LaunchAgent            - Einstellungen-Fenster
                                   - CSV/PDF-Export

        ┌──────────────┐
        │  SQLite DB   │
        │  (WAL mode)  │
        │ ~/.overtime-  │
        │  tracker/    │
        │  overtime.db │
        └──────────────┘
```

Die SwiftUI-App liest die gleiche SQLite-Datenbank, die der Python-Tracker beschreibt. WAL-Modus erlaubt concurrent reads (Swift) + writes (Python).

---

## 3. Design-Spezifikation

### 3.1 Allgemeines Design

- **Theme:** macOS Dark Mode
- **Schriftart:** SF Pro (System-Font), SF Mono für Zahlen/Code
- **Farbpalette:**

| Verwendung | Farbe | Hex |
|---|---|---|
| Reguläre Arbeitszeit | Apple Blue | `#007AFF` |
| Overtime | Apple Red | `#FF453A` |
| Idle | Gray | `#636366` |
| Erste/letzte Aktivität | Apple Green | `#30D158` |
| Hintergrund | macOS Dark | `#1C1C1E` |
| Karten-Hintergrund | Leicht heller | `rgba(255,255,255,0.03)` |
| Primärtext | Light Gray | `#E5E5EA` |
| Sekundärtext | Medium Gray | `#8E8E93` |
| Tertiärtext | Dark Gray | `#636366` |

- **Tabular Nums:** Alle Zahlen mit `fontVariantNumeric: tabular-nums` bzw. `.monospacedDigit()` in SwiftUI
- **Keine Emojis, keine Icons außer Systemsymbolen (SF Symbols)**

### 3.2 Menüleisten-Icon

- Zeigt in der macOS-Menüleiste: `1:07 OT` (Stunden:Minuten Overtime heute)
- Farbe: Rot (`#FF453A`)
- Schrift: SF Mono, fett
- Bei pausiertem Tracking: `PAUSED`
- Klick öffnet das Popover

### 3.3 Popover (NSPopover)

Kompaktes Fenster, das direkt aus der Menüleiste erscheint. Breite: ~320px.

**Inhalt von oben nach unten:**

1. **Heute-Sektion**
   - Überschrift: `HEUTE — Montag, 02.03.` (Caps, klein, grau)
   - Drei Stat-Karten nebeneinander: Aktiv (blau), Overtime (rot), Idle (grau)
   - Zeile: "Erste / letzte Aktivität" mit Zeitspanne rechts

2. **Trennlinie**

3. **KW-Sektion**
   - Überschrift: `KW 9` (Caps, klein, grau)
   - Mini-Barchart: 7 Balken (Mo–So), Höhe proportional zur aktiven Zeit
     - Mo–Fr: Blau, mit rotem Anteil oben für Overtime
     - Sa–So: Komplett rot (wenn Aktivität vorhanden)
     - Leere Tage: Minimale graue Linie
   - Zwei Stat-Karten: Aktiv (blau), Overtime (rot)

4. **Trennlinie**

5. **Aktions-Buttons**
   - "Dashboard öffnen" → öffnet Dashboard-Fenster
   - "Tracking pausieren" → Toggle, subtiler Stil
   - "Einstellungen" → öffnet Settings-Fenster, subtiler Stil

### 3.4 Dashboard-Fenster

Eigenständiges macOS-Fenster. Breite: ~780px. Mit Titelleiste und Ampel-Buttons.

**Tab-Leiste:** Heute | Woche | Monat | Export

#### Tab: Heute

- **Metric Cards** (4er Grid): Aktive Zeit, Overtime, Idle, Erste/letzte Aktivität
- **App-Aufschlüsselung** (siehe 3.6)

#### Tab: Woche

- **Metric Cards** (2er Grid): Gesamte aktive Zeit, Gesamte Overtime
- **Tagesübersicht** als Stacked-Bar-Chart:
  - 7 Balken (Mo–So)
  - Blauer Anteil (regulär) unten, roter Anteil (Overtime) oben
  - Wert über jedem Balken (z.B. `8:30`)
  - Legende: Regulär (blau), Overtime (rot)
- **Detail-Tabelle:** Tag | Aktiv | Overtime | Erste/letzte Akt.
- **App-Aufschlüsselung** (siehe 3.6)

#### Tab: Monat

- **Metric Cards** (3er Grid): Monats-Overtime, Gesamte aktive Zeit, Arbeitstage
- **Kumulierte Overtime** als Area-Chart:
  - X-Achse: Tage des Monats
  - Y-Achse: Kumulierte Overtime in Stunden
  - Rote Linie mit rotem Gradient darunter
- **App-Aufschlüsselung** (siehe 3.6)

#### Tab: Export

- Datumsbereich-Auswahl (Von / Bis)
- Buttons: "CSV exportieren", "PDF-Report"
- Vorschau: Anzahl Datensätze, Anzahl Tage
- Code-Vorschau der ersten Zeilen (Monospace)

### 3.5 Einstellungen-Fenster

Eigenständiges Fenster, ~400px breit. Vier Sektionen:

#### Arbeitszeiten

- **Kernzeit Beginn:** Stepper (±15 Min), z.B. `09:00`
- **Kernzeit Ende:** Stepper (±15 Min), z.B. `18:00`
- **Arbeitstage:** 7 klickbare Tages-Pillen (Mo–So), aktive = blau, inaktive = grau
- Hinweistext: "Aktivität außerhalb dieser Tage und Zeiten wird als Overtime gezählt."

#### Tracking

- **Idle-Timeout:** Stepper (±1 Min), z.B. `10 Min`
- Hinweistext: "Nach dieser Zeit ohne Tastatur-/Maus-Aktivität wird die Zeit nicht mehr als Arbeitszeit gezählt."

#### System

- **Beim Login starten:** Toggle
- **Im Dock anzeigen:** Toggle

#### Daten

- **Datenbank-Pfad:** Anzeige (read-only), z.B. `~/.overtime-tracker/`
- **Alle Daten löschen:** Destruktiver Button (rot)

Versionsnummer am unteren Rand.

### 3.6 App-Aufschlüsselung (wiederverwendbare Komponente)

Erscheint in allen drei Tabs (Heute, Woche, Monat) mit jeweils passendem Zeitraum.

**Aufbau:**

- Überschrift links (z.B. "App-Aufschlüsselung" / "App-Aufschlüsselung (Woche)" / "App-Aufschlüsselung (Februar)")
- **Filter-Toggle rechts:** `Alle` | `Regulär` | `Overtime`
  - "Alle" = weißer Hintergrund wenn aktiv
  - "Regulär" = blauer Hintergrund wenn aktiv
  - "Overtime" = roter Hintergrund wenn aktiv

**Balken-Darstellung:**

- Max. 8 Apps anzeigen
- Jede Zeile: App-Name (rechts-aligned, 74px breit) | Balken | Zeitwert
- Balkenlänge proportional zur App mit den meisten Minuten
- Balkenfarbe:
  - Filter "Alle": Gradient von Blau zu Rot (proportional zum Regulär/Overtime-Verhältnis)
  - Filter "Regulär": Blau
  - Filter "Overtime": Rot
- Zeitwert rechts in `Xh Ym`-Format

**Zweck:** Zeigt, welche Apps man in der Overtime-Zeit vs. regulärer Arbeitszeit nutzt. Typisch: Tools wie Terminal, Claude, DataGrip dominieren in der Overtime; Slack und Mail dominieren in der Kernzeit.

---

## 4. Datenmodell (bestehend)

Die SwiftUI-App muss diese SQLite-Tabellen lesen können:

### activity_log

| Spalte | Typ | Beschreibung |
|---|---|---|
| id | INTEGER PK | Auto-Increment |
| timestamp | TEXT | ISO-Format, Lokalzeit |
| app_name | TEXT | Name der aktiven App |
| bundle_id | TEXT | macOS Bundle-ID |
| is_idle | INTEGER | 0 = aktiv, 1 = idle |
| idle_seconds | REAL | Sekunden seit letztem Input |
| poll_interval | INTEGER | Polling-Intervall in Sekunden |

### daily_summary

| Spalte | Typ | Beschreibung |
|---|---|---|
| date | TEXT PK | YYYY-MM-DD |
| day_of_week | INTEGER | 0=Mo ... 6=So |
| total_active_minutes | REAL | Summe aktive Zeit |
| total_idle_minutes | REAL | Summe Idle-Zeit |
| overtime_minutes | REAL | Overtime-Anteil |
| first_activity | TEXT | HH:MM:SS |
| last_activity | TEXT | HH:MM:SS |
| work_category | TEXT | regular/overtime |

### app_daily_summary

| Spalte | Typ | Beschreibung |
|---|---|---|
| date | TEXT | YYYY-MM-DD |
| app_name | TEXT | App-Name |
| active_minutes | REAL | Aktive Minuten gesamt |
| regular_minutes | REAL | Davon in Kernzeit |
| overtime_minutes | REAL | Davon außerhalb Kernzeit |

### settings (Single-Row, id=1)

| Spalte | Typ | Default | Beschreibung |
|---|---|---|---|
| id | INTEGER PK | 1 | CHECK (id = 1) — immer genau eine Zeile |
| core_start_hour | INTEGER | 9 | Kernzeit Beginn (Stunde) |
| core_start_minute | INTEGER | 0 | Kernzeit Beginn (Minute) |
| core_end_hour | INTEGER | 18 | Kernzeit Ende (Stunde) |
| core_end_minute | INTEGER | 0 | Kernzeit Ende (Minute) |
| work_days | TEXT | `0,1,2,3` | Komma-separiert, 0=Mo ... 6=So |
| idle_timeout_seconds | INTEGER | 600 | Idle-Timeout in Sekunden |

**DB-Pfad:** `~/.overtime-tracker/overtime.db`
**Modus:** WAL (concurrent read/write)

---

## 5. Offene Fragen für die Implementierung

### 5.1 Idle-Timeout (ENTSCHIEDEN)

**Problem:** Aktuell ist der Idle-Timeout auf 10 Minuten hardcoded. Bei längeren Skript-Läufen (z.B. Royalty Statements am Wochenende) wird passive Beobachtung nicht als Arbeitszeit erfasst.

**Entscheidung:** Der Idle-Timeout wird als Einstellung in der App konfigurierbar — in der gleichen Settings-Sektion wie die Kernarbeitszeiten. Auswahl: **10 / 30 / 60 Minuten**. Default: 10 Min. Das deckt den "Monitoring-Modus"-Usecase ab, ohne eigene UI-Mechanik. Wer ein Skript laufen lässt, stellt auf 60 Min.

### 5.2 Freitags-Logik

**Entscheidung:** Freitag wird **nicht** als eigene Kategorie behandelt. Die bisherige `friday`-Kategorie im Code fällt weg. Wenn freitags gearbeitet wird und das nicht als Overtime gelten soll, pausiert der Nutzer das Tracking manuell. Das vereinfacht die Logik auf zwei Kategorien: `regular` und `overtime`.

**Implikation für Backend:** `config.py` muss angepasst werden – `get_work_category()` liefert nur noch `regular` oder `overtime`. Die `friday`-Logik wird entfernt. Default-Arbeitstage bleiben Mo–Do, sind aber über die Einstellungen konfigurierbar.

### 5.3 Soll-Stunden

**Entscheidung:** Keine Soll-Stunden-Anzeige. Der Laptop-Tracker erfasst nicht die volle Arbeitszeit (Meetings, Telefonate etc.). Ein Soll/Ist-Vergleich wäre irreführend. Die App zeigt nur gemessene Werte ohne Bewertung.

### 5.4 App-Aufschlüsselung nach Regulär/Overtime — UMGESETZT

**Lösung:** Backend erweitert (Lösung 1). `app_daily_summary` hat jetzt `regular_minutes` und `overtime_minutes`. Berechnung erfolgt im Python-Daemon via SQL `CASE WHEN` auf Basis der Kernzeiten.

### 5.5 Einstellungen-Persistenz — UMGESETZT

**Lösung:** SQLite-Tabelle `settings` (Lösung 2). Single-Row-Tabelle (`CHECK (id = 1)`) mit typisierten Spalten. Python-Daemon lädt Settings bei jedem Summary-Update (~alle 5 Min) via `config.reload_from_db()`. SwiftUI-App kann die gleiche Tabelle lesen und schreiben.

---

## 6. Implementierungs-Reihenfolge

### Phase 0: Backend vorbereiten (Python) — ERLEDIGT

- [x] `friday`-Kategorie aus `config.py` und `database.py` entfernt → nur noch `regular` / `overtime`
- [x] `app_daily_summary` um `regular_minutes` und `overtime_minutes` erweitert
- [x] `settings`-Tabelle in SQLite angelegt (Single-Row, typisierte Spalten)
- [x] Python-Daemon liest Config (Kernzeiten, Arbeitstage, Idle-Timeout) aus SQLite via `reload_from_db()`
- [x] Schema-Migration via `PRAGMA user_version` für bestehende DBs

### Phase 1: Swift-Grundgerüst — ERLEDIGT

- [x] Xcode-Projekt erstellen (macOS App, SwiftUI, GRDB.swift Dependency)
- [x] LSUIElement = true (kein Dock-Icon), App Sandbox deaktiviert
- [x] SQLite-Lesezugriff via GRDB.swift (read-only DatabasePool, WAL-Modus)
- [x] Menüleisten-Icon mit Overtime-Anzeige (`NSStatusItem` zeigt `X:XX OT`)
- [x] Popover mit Live-Daten (GRDB `ValueObservation` async streams)
- [x] Models: `DailySummary`, `AppDailySummary`, `TrackerSettings` (GRDB FetchableRecord + Decodable)
- [x] GRDB-dynamic Dependency entfernt (nur statische GRDB Library nötig)

### Phase 2: Popover mit Live-Daten — ERLEDIGT

- [x] Popover-UI redesigned: Heute-Sektion (3 Stat-Cards + Aktivitäts-Zeile), KW-Sektion (Mini-Barchart + 2 Stat-Cards), Aktions-Buttons (Stubs)
- [x] Weekly SQLite-Query via GRDB `ValueObservation` (Mo–So der aktuellen ISO-Woche)
- [x] `WeekBarChart` Komponente: gestapelte Balken (regulär=blau, Overtime=rot, Wochenende=komplett rot)
- [x] Design-Farben als `Color`-Extension (`otBlue`, `otRed`, `otGray`, `otGreen`)
- [x] `StatCard` mit optionalem `accentColor`
- [x] Deutsche Locale für Datum-Header (`HEUTE — Montag, 02.03.`)
- [x] Popover-Höhe auf 460px angepasst

### Phase 3: Dashboard-Fenster — ERLEDIGT

- [x] `Formatters.swift` extrahiert: `formatMinutes()`, `formatTime()`, `formatHoursMinutes()`, `weekRange()`, `monthRange()`, `shortDate()`, `weekdayShort()` — `nonisolated enum` für MainActor-Kompatibilität
- [x] `DashboardViewModel`: `@Observable` mit separaten GRDB `ValueObservation`-Streams für Heute/Woche/Monat/Export, aggregierte App-Queries per `GROUP BY app_name, SUM()`
- [x] `AppBreakdownView`: Wiederverwendbare Komponente mit Filter-Toggle (Alle|Regulär|Overtime), max 8 Apps, horizontale Balken proportional
- [x] `DashboardBarChart`: Swift Charts `BarMark`, gestapelt (regulär=blau unten, Overtime=rot oben) mit `chartForegroundStyleScale`
- [x] `CumulativeOvertimeChart`: Swift Charts `AreaMark` + `LineMark`, kumulative Overtime pro Tag mit rotem Gradient
- [x] 4 Tab-Views: HeuteTab (4 Metric Cards), WocheTab (Bar Chart + Detail-Tabelle), MonatTab (Monats-Navigator + Area Chart), ExportTab (DatePicker + CSV-Export via `NSSavePanel`)
- [x] `DashboardView`: `TabView`-Container, `frame(minWidth: 780, minHeight: 600)`, Dark Mode
- [x] `AppDelegate.openDashboard()`: `NSWindow` + `NSHostingController`, `setFrameAutosaveName` für Position-Persistenz, `willCloseNotification` für ViewModel-Cleanup
- [x] PopoverView: "Dashboard öffnen" Button via `onOpenDashboard` Closure an AppDelegate angebunden

### Phase 3.5: User-Feedback — ERLEDIGT

Bugfixes und Verbesserungen aus manuellem Testing nach Phase 3.

- [x] Popover: Einstellungen-Button von Text auf Zahnrad-Icon (`gearshape` SF Symbol) geändert — macOS-Standard
- [x] AppBreakdownView: Picker-Label "Filter" verursachte Zeilenumbruch ("Fil-ter") → Label versteckt (`.labelsHidden()`)
- [x] ExportTab: Redundante "Kategorie"-Spalte entfernt — Spalten "Aktiv" und "Overtime" machen `workCategory` überflüssig (Vorschau + CSV)

### Phase 4: Einstellungen — ERLEDIGT

- [x] Python: Schema-Migration v2 — `core_start_minute`/`core_end_minute` Spalten, Overtime-SQL auf Minuten-Granularität
- [x] Python: `config.py` — `WorkSchedule` um Minuten-Felder erweitert, `is_core_hours()` vergleicht in Minuten
- [x] Swift: `TrackerSettings` → `Codable` + `PersistableRecord`, Minuten-Felder, Computed Helpers (`workDayInts`, `coreStartTotalMinutes`, `idleTimeoutMinutes`)
- [x] Swift: `DatabaseManager` — `saveSettings()` und `deleteAllData()` Write-Methoden
- [x] Swift: `LaunchAgentManager` — `nonisolated enum` wrapping `launchctl load/unload/list`
- [x] Swift: `SettingsViewModel` — `@Observable` mit ValueObservation, Auto-Save, Launch-at-Login Toggle, Dock-Visibility Toggle
- [x] Swift: `SettingsView` — 4 Sektionen (Arbeitszeiten, Tracking, System, Daten), ±15-Min-Stepper, Delete-Confirmation-Alert
- [x] Swift: `DayPillRow` — 7 Capsule-Buttons (Mo–So), min. 1 muss aktiv bleiben
- [x] Swift: `AppDelegate.openSettings()` — NSWindow-Pattern wie Dashboard, `applyDockVisibility()` beim Start
- [x] Swift: `PopoverViewModel` — `onOpenSettings` Closure, `isDaemonRunning` Check
- [x] Swift: `PopoverView` — Gear-Button verdrahtet, Daemon-Warnung wenn Python-Tracker nicht läuft

### Phase 5: Export + Polish

- [x] CSV-Export redesigned: Tidy-Format mit einer Zeile pro App pro Kategorie pro Tag (`Datum;App;Minuten;Kategorie`)
- [x] Export-Preview zeigt 5 Zeilen im neuen Format mit Summary-Zeile (Tage/Apps/Zeilen)
- [x] Testdaten-Seed auf 2 Wochen reduziert (2026-02-17 bis 2026-03-02), reproduzierbar via `random.seed(42)`
- PDF-Report — bewusst verschoben
- [x] App-Icon: `Contents.json` auf Single-Image-Format umgestellt (wartet auf 1024x1024 PNG vom User)
- [x] Launch at Login: Ein Toggle steuert Daemon (LaunchAgent) + Swift-App (`SMAppService.mainApp`)
- [x] LaunchAgent Auto-Install: `LaunchAgentManager.install()` schreibt plist automatisch, kein `install.sh` mehr nötig
- [x] NiceGUI-Dashboard entfernt: `src/dashboard.py` gelöscht, `nicegui` aus requirements.txt entfernt — SwiftUI-Dashboard ersetzt es vollständig
- Finale Tests

---

## 7. Referenzen

- **Mockup:** Das interaktive React-Mockup liegt im Chat-Verlauf und kann als visueller Referenzpunkt dienen
- **Bestehendes Repo:** https://github.com/buddemusicmatthias/overtime-tracker
- **SQLite-Schema:** Siehe `src/database.py` im Repo
- **Brainstorm-Dokument:** `docs/brainstorms/2026-02-27-overtime-tracker-brainstorm.md`
- **Implementierungsplan (Backend):** `docs/plans/2026-02-27-feat-overtime-tracker-macos-menubar-app-plan.md`

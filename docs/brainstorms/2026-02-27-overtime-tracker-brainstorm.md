# Overtime Tracker — Brainstorm

**Date:** 2026-02-27
**Status:** Draft

## What We're Building

Eine macOS-Menüleisten-App, die Überstunden automatisch erfasst — inklusive Idle-Erkennung und App-Tracking. Die App läuft im Hintergrund, startet automatisch beim Login und unterscheidet zwischen regulärer Arbeitszeit, Überstunden und Freitags-Ausgleich.

**Zielnutzer:** Matthias (Teamlead, 32h/Woche Mo-Do)
**Zweck:** Belastbare Zahlen für Gehaltsverhandlungen + Selbst-Awareness über Arbeitsmuster

## Why This Approach

**Tech-Stack: Python + rumps + NiceGUI + SQLite**

- rumps bietet eine simple API für macOS-Menüleisten-Apps (~20 Zeilen für Grundgerüst)
- NiceGUI-Erfahrung bereits vorhanden — Dashboard lässt sich schnell aufbauen
- pyobjc/Quartz für native macOS-APIs (aktive App, Idle-Detection)
- SQLite für lokale, leichtgewichtige Datenhaltung
- Alles Python, kein Sprachwechsel nötig

**Alternativen verworfen:**
- Streamlit: Einarbeitung nötig, eingeschränktere Interaktivität
- Swift/SwiftUI: Zu steile Lernkurve für den Zweck

## Key Decisions

### 1. Tracking-Granularität: App + Idle-Erkennung
- Erfasse welche App im Vordergrund ist + Zeitdauer
- Erkenne Leerlauf (>10 Min keine Maus-/Tastaturaktivität) und zähle das nicht als Arbeitszeit
- Polling-Intervall: alle 10-15 Sekunden (Balance zwischen Genauigkeit und Ressourcen)

### 2. Arbeitszeitmodell: Drei Kategorien
- **Reguläre Arbeitszeit:** Mo-Do, ca. 9:00-18:00 Uhr
- **Überstunden:** Mo-Do außerhalb Kernzeit + Sa/So
- **Freitag (Puffertag):** Wird erfasst und separat ausgewiesen — keine automatische Ausgleichs-Logik, einfach loggen (KISS)

### 3. App-Architektur: Menüleiste + Dashboard
- **Menüleisten-App (rumps):** Zeigt Quick-Übersicht im Dropdown (heutiger Tag, Wochensummary)
- **Dashboard (NiceGUI):** Separater lokaler Webserver mit Charts, Filtern, Wochen-/Monatsübersicht
- Button in der Menüleiste öffnet das Dashboard im Browser
- Autostart via macOS LaunchAgent

### 4. Datenhaltung: SQLite
- Lokale Datenbank, keine Cloud-Abhängigkeit
- Schema: Zeitstempel, App-Name, Aktivitätstyp (aktiv/idle), Arbeitskategorie

### 5. Export: CSV/Excel
- Rohdaten-Export für eigene Auswertungen
- PDF-Report ist nice-to-have für später

## MVP-Scope

**Phase 1 — Tracking-Core:**
- Hintergrund-Daemon der aktive App + Idle pollt
- SQLite-Logging
- Kernarbeitszeiten-Konfiguration

**Phase 2 — Menüleisten-App:**
- rumps-Integration
- Tagesübersicht im Dropdown
- Autostart-Setup (LaunchAgent)

**Phase 3 — Dashboard:**
- NiceGUI-Dashboard
- Überstunden pro Tag/Woche/Monat
- App-Aufschlüsselung
- CSV-Export

## Resolved Questions

1. **Idle-Timeout:** 10 Minuten — großzügig, damit Denkpausen als Arbeit zählen
2. **Kernzeiten-Flexibilität:** Globales Fenster (9-18 Uhr, Mo-Do) reicht aus
3. **Freitags-Logik:** Einfach loggen und separat ausweisen, keine spezielle Ausgleichs-Logik
4. **Datenschutz/Retention:** Unbegrenzt — langfristige Auswertungen und Verhandlungshistorie

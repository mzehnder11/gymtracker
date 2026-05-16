# GymTracker SwiftUI

Eine hochmoderne, native iOS-App zur Protokollierung von Krafttraining und zur Maximierung des **Progressive Overload**. GymTracker kombiniert präzises Datentracking mit Gamification-Elementen, um den Trainingsfortschritt nicht nur sichtbar, sondern erlebbar zu machen.

## Highlights der Version 2.0

*   **Gamification System**: Steige im Level auf! Sammle XP basierend auf deinem bewegten Gesamtvolumen und verfolge deine Trainings-Streaks.
*   **Intelligente Progression**: Erhalte automatisierte Empfehlungen für dein nächstes Training (Gewicht & Reps), basierend auf deiner Performance in der letzten Session.
*   **PR-Tracking (Recent Wins)**: Die App erkennt automatisch persönliche Rekorde und hebt deine Erfolge im Dashboard hervor.
*   **Swift 6 Concurrency**: Vollständig modernisiertes Backend, das die neuesten Swift-Nebenläufigkeitsregeln nutzt, um maximale Performance und Stabilität zu garantieren.
*   **JSON Backup & Restore**: Volle Datensouveränität durch einfachen Export und Import deines gesamten Trainingsverlaufs als JSON-Datei.

## Features

*   **Übungsverwaltung**: Erstellen und Organisieren von individuellen Übungen mit Ziel-Vorgaben für Sätze und Wiederholungen.
*   **Progressive Overload Analyse**:
    *   Automatische Berechnung des **geschätzten 1RM** (One-Rep Max) mittels der Brzycki-Formel.
    *   **Overload Score**: Prozentuale Steigerung seit dem ersten Log.
    *   Intensitäts-Scores basierend auf dem Volumen pro Satz.
*   **Detaillierte Charts (Swift Charts)**:
    *   **Performance-Graph**: Visualisierung der Trainingsfrequenz der letzten 7 Tage.
    *   **Übungs-Statistiken**: Intensitätsverlauf, Gewicht & Reps sowie Volumen-Analysen über die Zeit.
*   **Session-Tracking**: Protokollierung ganzer Trainingseinheiten mit Notizfunktion und automatischer Volumensummierung.
*   **Trainingspläne**: Erstellung von Vorlagen (z. B. Push/Pull/Legs), um Sessions mit einem Klick zu starten.

## Technologie-Stack

*   **Framework**: SwiftUI (modernstes deklaratives UI)
*   **Datenvisualisierung**: Swift Charts
*   **Sprache**: Swift 6 (Strict Concurrency & Sendability)
*   **Architektur**: MVVM (Model-View-ViewModel) mit modernem State Management
*   **Speicherung**: Codable & UserDefaults (Backup via JSON FileDocument)

## Projektstruktur

| Komponente | Beschreibung |
| --- | --- |
| `GymTrackerApp.swift` | Haupteinstiegspunkt der App. |
| `ContentView.swift` | Der Kern der App: Enthält UI-Komponenten, Models, Stores und die gesamte Geschäftslogik. |
| **Models** | `Exercise`, `WorkoutLog`, `TrainingSession`, `TrainingPlan`, `GymDataBackup`. |
| **Stores** | `GymStore` (Zentrale Logik, CRUD, Progression) & `SettingsStore` (Präferenzen). |
| **Views** | Dashboard, Übungsliste, Trainings-Modus, Detailansichten und Einstellungen. |

## Kernmetriken & Logik

Die App berechnet deinen Fortschritt dynamisch:

*   **XP & Level**: `1 Level = 5000 kg Gesamtvolumen`.
*   **Progression-Logik**: Wenn alle Sätze einer Übung im Zielbereich (targetRepsMax) absolviert wurden, schlägt die App eine Steigerung um 2.5kg vor.
*   **One-Rep Max (1RM)**: Berechnung nach Brzycki: `Gewicht * (1 + Reps / 30)`.
*   **Volumen**: `Gewicht * Wiederholungen`.

## Installation & Anforderungen

1.  **Xcode 15.0+**
2.  **iOS 17.0+** (erforderlich für Swift Charts und moderne NavigationStacks)
3.  Kopiere die Dateien in ein neues SwiftUI-Projekt.

---
*Entwickelt für Athleten, die Daten lieben.*

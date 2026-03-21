# GymTracker SwiftUI

Eine leistungsstarke, native iOS-App zum Verfolgen von Fitnesstraining, Kraftwerten und dem **Progressive Overload**. Die App ermöglicht es Nutzern, Übungen zu erstellen, Trainingseinheiten (Sessions) zu protokollieren und langfristige Trainingspläne zu verwalten.

## Features

* **Übungsverwaltung**: Erstellen und Organisieren von individuellen Übungen.
* **Progressive Overload Analyse**:
* Automatische Berechnung des **geschätzten 1RM** (One-Rep Max) mittels der Brzycki-Formel: .
* Visuelle Darstellung der Kraftsteigerung in Prozent.
* Intensitäts-Scores basierend auf dem Volumen ().


* **Detaillierte Charts**:
* **Intensitätsverlauf**: Visualisierung des Progressive Overload über die Zeit.
* **Gewicht & Reps**: Kombinierte Ansicht von Last und Wiederholungen.
* **Volumen-Bars**: Tracking des Gesamtvolumens pro Satz.


* **Session-Tracking**: Protokollierung ganzer Trainingseinheiten mit Notizfunktion.
* **Trainingspläne**: Erstellung von Vorlagen (z. B. Push/Pull/Legs), um Sessions mit einem Klick zu starten.
* **Persistence**: Lokale Speicherung aller Daten via `UserDefaults` (JSON Encoding).

## Technologie-Stack

* **Framework**: SwiftUI
* **Datenvisualisierung**: Swift Charts
* **Architektur**: MVVM (Model-View-ViewModel) mit `ObservableObject`
* **Speicherung**: Codable & UserDefaults

## Projektstruktur

| Datei | Beschreibung |
| --- | --- |
| `GymTrackerApp.swift` | Der Haupteinstiegspunkt der App (`@main`). |
| `ContentView.swift` | Enthält das gesamte UI, die Logik und die Datenmodelle. |
| **Models** | `Exercise`, `WorkoutLog`, `TrainingSession`, `TrainingPlan`. |
| **Store** | `GymStore` – Zentrale Logik für CRUD-Operationen und Persistenz. |
| **Views** | Modulare Subviews für Listen, Details, Diagramme und Formulare. |

## Kernmetriken & Logik

Die App berechnet den Fortschritt dynamisch:

* **Progressive Overload Score**: Vergleicht das Volumen des allerersten Logs mit dem des letzten Logs, um die prozentuale Steigerung zu ermitteln.
* **Volumen**: Berechnet als .
* **Durchschnittliche Intensität**: Arithmetisches Mittel des Volumens über alle Sätze einer Übung.

## Screenshots (Funktionsübersicht)

1. **Übungen**: Liste aller Übungen mit 1RM-Anzeige und Trend-Pfeilen.
2. **Statistiken**: Detaillierte Detailansicht einer Übung mit drei verschiedenen Chart-Typen.
3. **Sessions**: Übersicht über absolvierte Trainings mit automatischer Volumensummierung.
4. **Pläne**: Vorlagenverwaltung zum schnellen Starten von Workouts.

## Installation & Anforderungen

1. Xcode 15.0+ oder neuer.
2. iOS 17.0+ (aufgrund der Verwendung von Swift Charts und modernen NavigationStacks).
3. Einfach die `.swift` Dateien in ein neues Xcode-Projekt (SwiftUI App) kopieren.

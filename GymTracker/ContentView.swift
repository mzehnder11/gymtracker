import SwiftUI
import Foundation
import Charts
import Combine
import UniformTypeIdentifiers

// MARK: - DATE FORMATTER

extension Date {
    func formattedString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

// MARK: - MODELS

enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest = "Brust"
    case back = "Rücken"
    case legs = "Beine"
    case shoulders = "Schultern"
    case biceps = "Bizeps"
    case triceps = "Trizeps"
    case core = "Kern/Bauch"
    
    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .legs: return "figure.run"
        case .shoulders: return "figure.arms.open"
        case .biceps: return "figure.strengthtraining.traditional"
        case .triceps: return "figure.strengthtraining.traditional"
        case .core: return "figure.core.training"
        }
    }
}

struct Exercise: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var logs: [WorkoutLog]
    var muscleGroups: [MuscleGroup]
    
    // Progression Settings
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetSets: Int
    var autoProgression: Bool
    
    init(id: UUID = UUID(), name: String, logs: [WorkoutLog] = [], muscleGroups: [MuscleGroup] = [], targetRepsMin: Int = 8, targetRepsMax: Int = 12, targetSets: Int = 3, autoProgression: Bool = true) {
        self.id = id
        self.name = name
        self.logs = logs
        self.muscleGroups = muscleGroups
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetSets = targetSets
        self.autoProgression = autoProgression
    }
    
    // Backward Compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, logs, muscleGroups, targetRepsMin, targetRepsMax, targetSets, autoProgression
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        logs = try container.decode([WorkoutLog].self, forKey: .logs)
        muscleGroups = try container.decodeIfPresent([MuscleGroup].self, forKey: .muscleGroups) ?? []
        targetRepsMin = try container.decodeIfPresent(Int.self, forKey: .targetRepsMin) ?? 8
        targetRepsMax = try container.decodeIfPresent(Int.self, forKey: .targetRepsMax) ?? 12
        targetSets = try container.decodeIfPresent(Int.self, forKey: .targetSets) ?? 3
        autoProgression = try container.decodeIfPresent(Bool.self, forKey: .autoProgression) ?? true
    }
    
    var estimatedOneRepMax: Double? {
        guard let lastLog = logs.last else { return nil }
        if lastLog.reps == 1 {
            return lastLog.weight
        }
        return lastLog.weight * (1 + Double(lastLog.reps) / 30.0)
    }
    
    // Progressive Overload Metriken
    var progressiveOverloadScore: Double? {
        guard logs.count >= 2 else { return nil }
        let sortedLogs = logs.sorted { $0.date < $1.date }
        let first = sortedLogs.first!
        let last = sortedLogs.last!
        
        let firstScore = first.weight * Double(first.reps)
        let lastScore = last.weight * Double(last.reps)
        
        return ((lastScore - firstScore) / firstScore) * 100
    }
    
    var averageIntensity: Double? {
        guard !logs.isEmpty else { return nil }
        let totalIntensity = logs.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        return totalIntensity / Double(logs.count)
    }
}

struct WorkoutLog: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let weight: Double
    let reps: Int
    let sessionId: UUID?
    var isPR: Bool = false
    
    var volume: Double {
        weight * Double(reps)
    }
    
    // Intensitätsscore für Progressive Overload
    var intensityScore: Double {
        weight * Double(reps)
    }
}

struct TrainingSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var date: Date
    var exerciseIds: [UUID]
    var notes: String
    
    func totalVolume(from store: GymStore) -> Double {
        var total = 0.0
        for exercise in store.exercises where exerciseIds.contains(exercise.id) {
            for log in exercise.logs where log.sessionId == id {
                total += log.volume
            }
        }
        return total
    }
}

struct TrainingPlan: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var exerciseIds: [UUID]
    var notes: String
}

// MARK: - BACKUP MODELS

struct GymDataBackup: Codable, Sendable {
    var exercises: [Exercise]
    var sessions: [TrainingSession]
    var plans: [TrainingPlan]
    var version: String = "1.0"
}

struct GymDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var backup: GymDataBackup

    init(backup: GymDataBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.backup = try JSONDecoder().decode(GymDataBackup.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - SETTINGS STORE

final class SettingsStore: ObservableObject {
    @Published var appearanceMode: ColorScheme? {
        didSet { saveAppearance() }
    }
    
    @Published var weightUnit: WeightUnit = .kg {
        didSet { UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnit") }
    }
    
    @Published var showProgressIndicators: Bool = true {
        didSet { UserDefaults.standard.set(showProgressIndicators, forKey: "showProgressIndicators") }
    }
    
    @Published var defaultRestTimer: Int = 90 {
        didSet { UserDefaults.standard.set(defaultRestTimer, forKey: "defaultRestTimer") }
    }
    
    @Published var soundEnabled: Bool = true {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    
    @Published var hapticFeedback: Bool = true {
        didSet { UserDefaults.standard.set(hapticFeedback, forKey: "hapticFeedback") }
    }
    
    enum WeightUnit: String, Codable, CaseIterable {
        case kg = "kg"
        case lbs = "lbs"
        
        var name: String {
            switch self {
            case .kg: return "Kilogramm (kg)"
            case .lbs: return "Pfund (lbs)"
            }
        }
    }
    
    init() {
        loadAppearance()
        
        if let unit = UserDefaults.standard.string(forKey: "weightUnit"),
           let weightUnit = WeightUnit(rawValue: unit) {
            self.weightUnit = weightUnit
        }
        
        self.showProgressIndicators = UserDefaults.standard.object(forKey: "showProgressIndicators") as? Bool ?? true
        self.defaultRestTimer = UserDefaults.standard.object(forKey: "defaultRestTimer") as? Int ?? 90
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.hapticFeedback = UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool ?? true
    }
    
    private func saveAppearance() {
        if let mode = appearanceMode {
            UserDefaults.standard.set(mode == .dark ? "dark" : "light", forKey: "appearanceMode")
        } else {
            UserDefaults.standard.removeObject(forKey: "appearanceMode")
        }
    }
    
    private func loadAppearance() {
        if let saved = UserDefaults.standard.string(forKey: "appearanceMode") {
            appearanceMode = saved == "dark" ? .dark : .light
        } else {
            appearanceMode = nil
        }
    }
}

// MARK: - STORE (Persistence)

final class GymStore: ObservableObject {
    
    @Published var exercises: [Exercise] = []
    @Published var sessions: [TrainingSession] = []
    @Published var plans: [TrainingPlan] = []
    
    private let exercisesKey = "gym_data"
    private let sessionsKey = "gym_sessions"
    private let plansKey = "gym_plans"
    
    init() {
        load()
    }
    
    func addExercise(name: String, muscleGroups: [MuscleGroup] = [], targetRepsMin: Int = 8, targetRepsMax: Int = 12, targetSets: Int = 3) {
        let exercise = Exercise(
            id: UUID(),
            name: name,
            logs: [],
            muscleGroups: muscleGroups,
            targetRepsMin: targetRepsMin,
            targetRepsMax: targetRepsMax,
            targetSets: targetSets,
            autoProgression: true
        )
        exercises.append(exercise)
        save()
    }
    
    func updateExercise(_ exercise: Exercise, name: String, muscleGroups: [MuscleGroup], targetRepsMin: Int, targetRepsMax: Int, targetSets: Int, autoProgression: Bool) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[index].name = name
        exercises[index].muscleGroups = muscleGroups
        exercises[index].targetRepsMin = targetRepsMin
        exercises[index].targetRepsMax = targetRepsMax
        exercises[index].targetSets = targetSets
        exercises[index].autoProgression = autoProgression
        save()
    }
    
    func deleteExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
        save()
    }
    
    func addLog(to exercise: Exercise, weight: Double, reps: Int, sessionId: UUID? = nil) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        let isPR = checkPR(for: exercises[index], weight: weight, reps: reps)
        
        let log = WorkoutLog(
            id: UUID(),
            date: Date(),
            weight: weight,
            reps: reps,
            sessionId: sessionId,
            isPR: isPR
        )
        exercises[index].logs.append(log)
        save()
    }
    
    func updateLog(exerciseId: UUID, log: WorkoutLog, weight: Double, reps: Int) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let logIndex = exercises[exerciseIndex].logs.firstIndex(where: { $0.id == log.id }) else { return }
        
        let updatedLog = WorkoutLog(
            id: log.id,
            date: log.date,
            weight: weight,
            reps: reps,
            sessionId: log.sessionId
        )
        exercises[exerciseIndex].logs[logIndex] = updatedLog
        save()
    }
    
    func deleteLog(exerciseId: UUID, logId: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        exercises[exerciseIndex].logs.removeAll { $0.id == logId }
        save()
    }
    
    func addSession(name: String, exerciseIds: [UUID], notes: String = "") {
        let session = TrainingSession(
            id: UUID(),
            name: name,
            date: Date(),
            exerciseIds: exerciseIds,
            notes: notes
        )
        sessions.append(session)
        save()
    }
    
    func updateSession(_ session: TrainingSession, name: String, exerciseIds: [UUID], notes: String) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index].name = name
        sessions[index].exerciseIds = exerciseIds
        sessions[index].notes = notes
        save()
    }
    
    func deleteSession(_ session: TrainingSession) {
        for exerciseIndex in exercises.indices {
            exercises[exerciseIndex].logs.removeAll { $0.sessionId == session.id }
        }
        sessions.removeAll { $0.id == session.id }
        save()
    }
    
    func addPlan(name: String, exerciseIds: [UUID], notes: String = "") {
        let plan = TrainingPlan(
            id: UUID(),
            name: name,
            exerciseIds: exerciseIds,
            notes: notes
        )
        plans.append(plan)
        save()
    }
    
    func updatePlan(_ plan: TrainingPlan, name: String, exerciseIds: [UUID], notes: String) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[index].name = name
        plans[index].exerciseIds = exerciseIds
        plans[index].notes = notes
        save()
    }
    
    func deletePlan(_ plan: TrainingPlan) {
        plans.removeAll { $0.id == plan.id }
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: exercisesKey)
        }
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: plansKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: exercisesKey),
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            exercises = decoded
        }
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([TrainingSession].self, from: data) {
            sessions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: plansKey),
           let decoded = try? JSONDecoder().decode([TrainingPlan].self, from: data) {
            plans = decoded
        }
    }
    
    // MARK: - Gamification & Progression Helpers
    
    func weeklySets(for muscleGroup: MuscleGroup) -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return 0 }
        
        var count = 0
        for exercise in exercises where exercise.muscleGroups.contains(muscleGroup) {
            count += exercise.logs.filter { $0.date >= startOfWeek }.count
        }
        return count
    }
    
    func checkPR(for exercise: Exercise, weight: Double, reps: Int) -> Bool {
        guard !exercise.logs.isEmpty else { return true }
        
        for log in exercise.logs {
            if log.weight > weight { return false }
            if log.weight == weight && log.reps >= reps { return false }
        }
        return true
    }
    
    func progressionRecommendation(for exercise: Exercise) -> (weight: Double, reps: Int)? {
        guard exercise.autoProgression else { return nil }
        
        // Letzte Session finden, in der diese Übung vorkam
        let sortedLogs = exercise.logs.sorted(by: { $0.date > $1.date })
        guard let lastSessionId = sortedLogs.first?.sessionId else { return nil }
        
        let sessionLogs = exercise.logs.filter { $0.sessionId == lastSessionId }
        
        // Alle Sätze müssen das Maximum erreicht haben
        let hitTarget = sessionLogs.count >= exercise.targetSets && 
                       sessionLogs.allSatisfy { $0.reps >= exercise.targetRepsMax }
        
        if hitTarget {
            let lastWeight = sessionLogs.first?.weight ?? 0
            return (weight: lastWeight + 2.5, reps: exercise.targetRepsMin)
        } else {
            // Wenn nicht gesteigert wird, nimm das letzte Gewicht
            let lastWeight = sortedLogs.first?.weight ?? 0
            return (weight: lastWeight, reps: exercise.targetRepsMax)
        }
    }
    
    func getStreak() -> Int {
        let calendar = Calendar.current
        let sortedSessions = sessions.sorted(by: { $0.date > $1.date })
        guard !sortedSessions.isEmpty else { return 0 }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        // Sehr vereinfachte Streak-Logik für Demo: aufeinanderfolgende Tage mit Training
        // In einem echten Szenario würde man Wochen oder geplante Workouts zählen
        for session in sortedSessions {
            let sessionDate = calendar.startOfDay(for: session.date)
            if sessionDate == currentDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if sessionDate < currentDate {
                break
            }
        }
        return streak
    }
    
    func createBackup() -> GymDataBackup {
        return GymDataBackup(exercises: exercises, sessions: sessions, plans: plans)
    }
    
    func restore(from backup: GymDataBackup) {
        self.exercises = backup.exercises
        self.sessions = backup.sessions
        self.plans = backup.plans
        save()
    }
    
    func clearAll() {
        exercises.removeAll()
        sessions.removeAll()
        plans.removeAll()
        UserDefaults.standard.removeObject(forKey: exercisesKey)
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: plansKey)
    }
}

// MARK: - CONTENT VIEW

struct ContentView: View {
    
    @StateObject private var store = GymStore()
    @StateObject private var settings = SettingsStore()
    
    var body: some View {
        TabView {
            DashboardView()
                .environmentObject(store)
                .environmentObject(settings)
                .tabItem {
                    Label("Übersicht", systemImage: "house.fill")
                }

            ExercisesListView()
                .environmentObject(store)
                .environmentObject(settings)
                .tabItem {
                    Label("Übungen", systemImage: "dumbbell")
                }
            
            TrainingView()
                .environmentObject(store)
                .environmentObject(settings)
                .tabItem {
                    Label("Training", systemImage: "figure.run.circle")
                }
            
            SettingsView()
                .environmentObject(store)
                .environmentObject(settings)
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(settings.appearanceMode)
    }
}

// MARK: - DASHBOARD VIEW

struct DashboardView: View {
    @EnvironmentObject var store: GymStore
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Header mit Streak
                    HStack {
                        VStack(alignment: .leading) {
                            Text(Date().formattedString())
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Dein Fortschritt")
                                .font(.title.bold())
                        }
                        Spacer()
                        StreakBadge(count: store.getStreak())
                    }
                    .padding(.horizontal)
                    
                    // Aktivitäts-Chart (Apple Fitness Style)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Aktivität (letzte 7 Tage)")
                            .font(.headline)
                        
                        Chart {
                            ForEach(lastSevenDays(), id: \.date) { data in
                                BarMark(
                                    x: .value("Tag", data.date, unit: .day),
                                    y: .value("Sätze", data.count)
                                )
                                .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top))
                                .cornerRadius(4)
                            }
                        }
                        .frame(height: 120)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Muskelgruppen-Ringe
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Wöchentliches Volumen (Sätze)")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(MuscleGroup.allCases, id: \.self) { group in
                                    MuscleGroupRing(muscleGroup: group, setsDone: store.weeklySets(for: group))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                    }
                    
                    // Letzte Erfolge (PRs)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Deine Meilensteine")
                            .font(.headline)
                        
                        let prLogs = store.exercises.flatMap { ex in 
                            ex.logs.filter { $0.isPR }.map { (ex.name, $0) } 
                        }.sorted(by: { $0.1.date > $1.1.date }).prefix(5)
                        
                        if prLogs.isEmpty {
                            Text("Noch keine PRs aufgezeichnet. Gib Gas!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        } else {
                            ForEach(prLogs, id: \.1.id) { pr in
                                HStack {
                                    Text("👑")
                                    VStack(alignment: .leading) {
                                        Text(pr.0)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                        Text("\(String(format: "%.1f", pr.1.weight)) kg × \(pr.1.reps)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(pr.1.date.formattedString())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
    
    struct ActivityData {
        let date: Date
        let count: Int
    }
    
    private func lastSevenDays() -> [ActivityData] {
        let calendar = Calendar.current
        return (0...6).reversed().map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date()))!
            let count = store.exercises.reduce(0) { total, ex in
                total + ex.logs.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
            }
            return ActivityData(date: date, count: count)
        }
    }
}

struct MuscleGroupRing: View {
    let muscleGroup: MuscleGroup
    let setsDone: Int
    let goal: Int = 15 // Durchschnittliches Ziel: 15 Sätze pro Woche
    
    var progress: Double {
        min(Double(setsDone) / Double(goal), 1.0)
    }
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: progress)
                
                Image(systemName: muscleGroup.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(progress >= 1.0 ? .orange : .primary)
            }
            .frame(width: 70, height: 70)
            
            Text(muscleGroup.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

struct StreakBadge: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text("\(count)")
                .fontWeight(.bold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - EXERCISES LIST

struct ExercisesListView: View {
    
    @EnvironmentObject var store: GymStore
    @State private var showAddExercise = false
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return store.exercises
        } else {
            return store.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                            .environmentObject(store)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                if let oneRM = exercise.estimatedOneRepMax {
                                    Text("1RM: \(String(format: "%.1f", oneRM)) kg")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let progress = exercise.progressiveOverloadScore {
                                    HStack(spacing: 2) {
                                        Image(systemName: progress >= 0 ? "arrow.up.right" : "arrow.down.right")
                                            .font(.caption2)
                                        Text("\(String(format: "%.1f", abs(progress)))%")
                                            .font(.caption)
                                    }
                                    .foregroundColor(progress >= 0 ? .green : .red)
                                }
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        store.deleteExercise(store.exercises[index])
                    }
                }
            }
            .navigationTitle("Übungen")
            .toolbar {
                Button {
                    showAddExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseView()
                    .environmentObject(store)
            }
            .searchable(text: $searchText, prompt: "Übung suchen")
        }
    }
}

// MARK: - ADD/EDIT EXERCISE

struct AddExerciseView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: GymStore
    
    let exerciseToEdit: Exercise?
    @State private var name = ""
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []
    @State private var targetRepsMin = 8
    @State private var targetRepsMax = 12
    @State private var targetSets = 3
    @State private var autoProgression = true
    
    init(exerciseToEdit: Exercise? = nil) {
        self.exerciseToEdit = exerciseToEdit
        _name = State(initialValue: exerciseToEdit?.name ?? "")
        _selectedMuscleGroups = State(initialValue: Set(exerciseToEdit?.muscleGroups ?? []))
        _targetRepsMin = State(initialValue: exerciseToEdit?.targetRepsMin ?? 8)
        _targetRepsMax = State(initialValue: exerciseToEdit?.targetRepsMax ?? 12)
        _targetSets = State(initialValue: exerciseToEdit?.targetSets ?? 3)
        _autoProgression = State(initialValue: exerciseToEdit?.autoProgression ?? true)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Allgemein") {
                    TextField("Übungsname", text: $name)
                }
                
                Section("Muskelgruppen") {
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        Button {
                            if selectedMuscleGroups.contains(group) {
                                selectedMuscleGroups.remove(group)
                            } else {
                                selectedMuscleGroups.insert(group)
                            }
                        } label: {
                            HStack {
                                Label(group.rawValue, systemImage: group.icon)
                                Spacer()
                                if selectedMuscleGroups.contains(group) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("Ziel-Fenster (Coaching)") {
                    Stepper("Sätze: \(targetSets)", value: $targetSets, in: 1...10)
                    Stepper("Min. Reps: \(targetRepsMin)", value: $targetRepsMin, in: 1...50)
                    Stepper("Max. Reps: \(targetRepsMax)", value: $targetRepsMax, in: targetRepsMin...50)
                    
                    Toggle("Autom. Steigerung", isOn: $autoProgression)
                }
            }
            .navigationTitle(exerciseToEdit == nil ? "Neue Übung" : "Übung bearbeiten")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(exerciseToEdit == nil ? "Hinzufügen" : "Speichern") {
                        if let exercise = exerciseToEdit {
                            store.updateExercise(
                                exercise, 
                                name: name, 
                                muscleGroups: Array(selectedMuscleGroups), 
                                targetRepsMin: targetRepsMin, 
                                targetRepsMax: targetRepsMax, 
                                targetSets: targetSets, 
                                autoProgression: autoProgression
                            )
                        } else {
                            store.addExercise(
                                name: name, 
                                muscleGroups: Array(selectedMuscleGroups), 
                                targetRepsMin: targetRepsMin, 
                                targetRepsMax: targetRepsMax, 
                                targetSets: targetSets
                            )
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - EXERCISE DETAIL

struct ExerciseDetailView: View {
    
    let exercise: Exercise
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddLog = false
    @State private var showEditExercise = false
    @State private var logToEdit: WorkoutLog?
    
    var currentExercise: Exercise? {
        store.exercises.first { $0.id == exercise.id }
    }
    
    var totalVolume: Double {
        currentExercise?.logs.reduce(0) { $0 + $1.volume } ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Progressive Overload Highlight
                if let ex = currentExercise, ex.logs.count >= 2 {
                    ProgressiveOverloadCard(exercise: ex)
                }
                
                // Statistiken
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistiken")
                        .font(.headline)
                    
                    HStack {
                        StatCard(title: "Gesamt-Volumen", value: "\(String(format: "%.0f", totalVolume)) kg")
                        StatCard(title: "Trainings", value: "\(currentExercise?.logs.count ?? 0)")
                    }
                    
                    HStack {
                        if let oneRM = currentExercise?.estimatedOneRepMax {
                            StatCard(title: "Geschätztes 1RM", value: "\(String(format: "%.1f", oneRM)) kg")
                        }
                        
                        if let avgIntensity = currentExercise?.averageIntensity {
                            StatCard(title: "Ø Intensität", value: "\(String(format: "%.0f", avgIntensity)) kg")
                        }
                    }
                }
                
                // Progressive Overload Chart
                if let ex = currentExercise, ex.logs.count >= 2 {
                    Text("Progressive Overload")
                        .font(.headline)
                    progressiveOverloadChart(for: ex)
                }
                
                // Weitere Charts
                if let ex = currentExercise, !ex.logs.isEmpty {
                    Text("Gewicht & Wiederholungen")
                        .font(.headline)
                        .padding(.top)
                    combinedWeightRepsChart(for: ex)
                    
                    Text("Volumenverlauf")
                        .font(.headline)
                        .padding(.top)
                    volumeChart(for: ex)
                }
                
                Divider()
                
                // Logs mit Vergleich
                Text("Verlauf")
                    .font(.headline)
                
                if let ex = currentExercise {
                    let sortedLogs = ex.logs.sorted(by: { $0.date > $1.date })
                    ForEach(Array(sortedLogs.enumerated()), id: \.element.id) { index, log in
                        let previousLog = index < sortedLogs.count - 1 ? sortedLogs[index + 1] : nil
                        LogRowView(
                            log: log,
                            previousLog: previousLog,
                            onTap: {
                                logToEdit = log
                            },
                            onEdit: {
                                logToEdit = log
                            },
                            onDelete: {
                                store.deleteLog(exerciseId: exercise.id, logId: log.id)
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle(currentExercise?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddLog = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showEditExercise = true
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    store.deleteExercise(exercise)
                    dismiss()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showAddLog) {
            if let ex = currentExercise {
                AddLogView(exercise: ex)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showEditExercise) {
            if let ex = currentExercise {
                AddExerciseView(exerciseToEdit: ex)
                    .environmentObject(store)
            }
        }
        .sheet(item: $logToEdit) { log in
            if let ex = currentExercise {
                EditLogView(exercise: ex, log: log)
                    .environmentObject(store)
            }
        }
    }
    
    // MARK: - Charts
    
    private func progressiveOverloadChart(for exercise: Exercise) -> some View {
        Chart {
            ForEach(exercise.logs) { log in
                LineMark(
                    x: .value("Datum", log.date),
                    y: .value("Intensität", log.intensityScore)
                )
                .foregroundStyle(.purple)
                .symbol(Circle())
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Datum", log.date),
                    y: .value("Intensität", log.intensityScore)
                )
                .foregroundStyle(.purple)
            }
        }
        .chartYAxisLabel("Intensität (kg × reps)")
        .frame(height: 220)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func combinedWeightRepsChart(for exercise: Exercise) -> some View {
        Chart {
            ForEach(exercise.logs) { log in
                LineMark(
                    x: .value("Datum", log.date),
                    y: .value("Gewicht", log.weight)
                )
                .foregroundStyle(.blue)
                .symbol(Circle())
                
                BarMark(
                    x: .value("Datum", log.date),
                    y: .value("Wiederholungen", Double(log.reps))
                )
                .foregroundStyle(.orange.opacity(0.5))
            }
        }
        .frame(height: 200)
    }
    
    private func volumeChart(for exercise: Exercise) -> some View {
        Chart {
            ForEach(exercise.logs) { log in
                BarMark(
                    x: .value("Datum", log.date),
                    y: .value("Volumen", log.volume)
                )
                .foregroundStyle(.green)
            }
        }
        .frame(height: 200)
    }
}

// MARK: - PROGRESSIVE OVERLOAD CARD

struct ProgressiveOverloadCard: View {
    let exercise: Exercise
    
    var progressInfo: (change: Double, isPositive: Bool, text: String) {
        guard let score = exercise.progressiveOverloadScore else {
            return (0, false, "Keine Daten")
        }
        
        let isPositive = score >= 0
        let text: String
        
        if abs(score) < 5 {
            text = "Plateau"
        } else if abs(score) < 15 {
            text = isPositive ? "Leichte Steigerung" : "Leichter Rückgang"
        } else if abs(score) < 30 {
            text = isPositive ? "Gute Steigerung" : "Deutlicher Rückgang"
        } else {
            text = isPositive ? "Starke Steigerung! 💪" : "Starker Rückgang"
        }
        
        return (score, isPositive, text)
    }
    
    var body: some View {
        let info = progressInfo
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: info.isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundColor(info.isPositive ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progressive Overload")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(info.text)
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.1f", abs(info.change)))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(info.isPositive ? .green : .red)
                    Text("seit Start")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        info.isPositive ? Color.green.opacity(0.1) : Color.red.opacity(0.1),
                        info.isPositive ? Color.green.opacity(0.05) : Color.red.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - LOG ROW VIEW

struct LogRowView: View {
    let log: WorkoutLog
    let previousLog: WorkoutLog?
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showOptions = false
    
    var changes: (weight: Double, reps: Int, volume: Double)? {
        guard let prev = previousLog else { return nil }
        return (
            log.weight - prev.weight,
            log.reps - prev.reps,
            log.volume - prev.volume
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.date.formattedString())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                Button {
                    showOptions = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(format: "%.1f", log.weight)) kg × \(log.reps)")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("Volumen: \(String(format: "%.0f", log.volume)) kg")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if let changes = changes {
                    VStack(alignment: .trailing, spacing: 4) {
                        if changes.weight != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: changes.weight > 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                Text("\(String(format: "%.1f", abs(changes.weight))) kg")
                                    .font(.caption)
                            }
                            .foregroundColor(changes.weight > 0 ? .green : .red)
                        }
                        
                        if changes.reps != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: changes.reps > 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                Text("\(abs(changes.reps)) reps")
                                    .font(.caption)
                            }
                            .foregroundColor(changes.reps > 0 ? .green : .red)
                        }
                        
                        if changes.volume != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: changes.volume > 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption2)
                                Text("\(String(format: "%.0f", abs(changes.volume))) kg")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(changes.volume > 0 ? .green : .red)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
            
            Button {
                onEdit()
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .confirmationDialog("Eintrag bearbeiten", isPresented: $showOptions) {
            Button("Bearbeiten") {
                onEdit()
            }
            
            Button("Löschen", role: .destructive) {
                onDelete()
            }
            
            Button("Abbrechen", role: .cancel) {}
        }
    }
}

// MARK: - STAT CARD

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - ADD LOG

struct AddLogView: View {
    
    let exercise: Exercise
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight = ""
    @State private var reps = ""
    
    var lastLog: WorkoutLog? {
        exercise.logs.sorted { $0.date > $1.date }.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if let last = lastLog {
                    Section("Letztes Training") {
                        HStack {
                            Text("\(String(format: "%.1f", last.weight)) kg × \(last.reps)")
                            Spacer()
                            Text("Volumen: \(String(format: "%.0f", last.volume)) kg")
                                .foregroundColor(.secondary)
                        }
                        .font(.callout)
                    }
                }
                
                Section("Neues Training") {
                    TextField("Gewicht (kg)", text: $weight)
                        .keyboardType(.decimalPad)
                    
                    TextField("Wiederholungen", text: $reps)
                        .keyboardType(.numberPad)
                }
                
                if let w = Double(weight), let r = Int(reps) {
                    Section("Vorschau") {
                        HStack {
                            Text("Volumen:")
                            Spacer()
                            Text("\(String(format: "%.0f", w * Double(r))) kg")
                                .fontWeight(.semibold)
                        }
                        
                        if let last = lastLog {
                            let volumeChange = (w * Double(r)) - last.volume
                            HStack {
                                Text("Veränderung:")
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: volumeChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.caption)
                                    Text("\(String(format: "%.0f", abs(volumeChange))) kg")
                                }
                                .foregroundColor(volumeChange >= 0 ? .green : .red)
                                .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Training eintragen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let w = Double(weight),
                           let r = Int(reps) {
                            store.addLog(to: exercise, weight: w, reps: r)
                            dismiss()
                        }
                    }
                    .disabled(weight.isEmpty || reps.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - EDIT LOG

struct EditLogView: View {
    
    let exercise: Exercise
    let log: WorkoutLog
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight = ""
    @State private var reps = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Gewicht (kg)", text: $weight)
                    .keyboardType(.decimalPad)
                
                TextField("Wiederholungen", text: $reps)
                    .keyboardType(.numberPad)
                
                if let w = Double(weight), let r = Int(reps) {
                    Section {
                        HStack {
                            Text("Volumen:")
                            Spacer()
                            Text("\(String(format: "%.0f", w * Double(r))) kg")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Log bearbeiten")
            .onAppear {
                weight = String(log.weight)
                reps = String(log.reps)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let w = Double(weight),
                           let r = Int(reps) {
                            store.updateLog(exerciseId: exercise.id, log: log, weight: w, reps: r)
                            dismiss()
                        }
                    }
                    .disabled(weight.isEmpty || reps.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - TRAINING VIEW (Combined Sessions & Plans)

struct TrainingView: View {
    @EnvironmentObject var store: GymStore
    @State private var selectedTab = 0
    @State private var showAddSession = false
    @State private var showAddPlan = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Ansicht", selection: $selectedTab) {
                    Text("Sessions").tag(0)
                    Text("Pläne").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    SessionsListViewContent()
                } else {
                    PlansListViewContent()
                }
            }
            .navigationTitle("Training")
            .toolbar {
                Button {
                    if selectedTab == 0 {
                        showAddSession = true
                    } else {
                        showAddPlan = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddSession) {
                AddSessionView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAddPlan) {
                AddPlanView()
                    .environmentObject(store)
            }
        }
    }
}

struct SessionsListViewContent: View {
    @EnvironmentObject var store: GymStore
    
    var body: some View {
        List {
            ForEach(store.sessions.sorted(by: { $0.date > $1.date })) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                        .environmentObject(store)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.name)
                            .font(.headline)
                        HStack {
                            Text(session.date.formattedString())
                            Spacer()
                            Text("Volumen: \(String(format: "%.0f", session.totalVolume(from: store))) kg")
                                .foregroundColor(.blue)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                let sortedSessions = store.sessions.sorted(by: { $0.date > $1.date })
                for index in indexSet {
                    store.deleteSession(sortedSessions[index])
                }
            }
        }
    }
}

struct PlansListViewContent: View {
    @EnvironmentObject var store: GymStore
    @State private var showStartSession = false
    @State private var currentPlan: TrainingPlan?

    var body: some View {
        List {
            ForEach(store.plans) { plan in
                NavigationLink {
                    PlanDetailView(plan: plan)
                        .environmentObject(store)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(plan.name)
                                .font(.headline)
                            Text("\(plan.exerciseIds.count) Übungen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            currentPlan = plan
                            showStartSession = true
                        } label: {
                            Text("Start")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain) // Prevents the button from triggering the NavigationLink
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        store.deletePlan(plan)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $showStartSession) {
            if let p = currentPlan {
                StartSessionFromPlanView(plan: p)
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - ADD SESSION

struct AddSessionView: View {
    
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var notes = ""
    @State private var selectedExerciseIds: Set<UUID> = []
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return store.exercises
        } else {
            return store.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Session-Name") {
                    TextField("z.B. Push Day", text: $name)
                }
                
                Section("Übungen auswählen") {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            if selectedExerciseIds.contains(exercise.id) {
                                selectedExerciseIds.remove(exercise.id)
                            } else {
                                selectedExerciseIds.insert(exercise.id)
                            }
                        } label: {
                            HStack {
                                Text(exercise.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedExerciseIds.contains(exercise.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Neue Session")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        store.addSession(
                            name: name,
                            exerciseIds: Array(selectedExerciseIds),
                            notes: notes
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedExerciseIds.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Übung suchen")
        }
    }
}

// MARK: - SESSION DETAIL

struct SessionDetailView: View {
    
    let session: TrainingSession
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedExercise: Exercise?
    @State private var showEditSession = false
    @State private var showSummary = false
    
    var currentSession: TrainingSession? {
        store.sessions.first { $0.id == session.id }
    }
    
    var sessionExercises: [Exercise] {
        guard let sess = currentSession else { return [] }
        return store.exercises.filter { sess.exerciseIds.contains($0.id) }
    }
    
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Info")
                        .font(.headline)
                    
                    if let sess = currentSession {
                        Text(sess.date.formattedString())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !sess.notes.isEmpty {
                            Text(sess.notes)
                                .font(.body)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        StatCard(
                            title: "Gesamt-Volumen",
                            value: "\(String(format: "%.0f", sess.totalVolume(from: store))) kg"
                        )
                    }
                }
                
                Divider()
                
                Text("Übungen")
                    .font(.headline)
                
                ForEach(sessionExercises) { exercise in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            selectedExercise = exercise
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    let sessionLogs = exercise.logs.filter { $0.sessionId == session.id }
                                    if !sessionLogs.isEmpty {
                                        Text("\(sessionLogs.count) Sätze")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Noch keine Sätze")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        let logs = exercise.logs.filter { $0.sessionId == session.id }
                        ForEach(logs) { log in
                            HStack {
                                if log.isPR {
                                    Text("👑")
                                        .shadow(radius: 2)
                                }
                                Text("\(String(format: "%.1f", log.weight)) kg × \(log.reps)")
                                Spacer()
                                Text("\(String(format: "%.0f", log.volume)) kg")
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            .font(.caption)
                        }
                    }
                }
                
                Button {
                    showSummary = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Session abschließen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle(currentSession?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSession = true
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    store.deleteSession(session)
                    dismiss()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            AddLogToSessionView(exercise: exercise, sessionId: session.id)
                .environmentObject(store)
        }
        .sheet(isPresented: $showSummary) {
            if let sess = currentSession {
                WorkoutSummaryView(session: sess)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showEditSession) {
            if let sess = currentSession {
                EditSessionView(session: sess)
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - WORKOUT SUMMARY VIEW

struct WorkoutSummaryView: View {
    let session: TrainingSession
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    var sessionPRs: [(String, WorkoutLog)] {
        store.exercises.flatMap { ex in
            ex.logs.filter { $0.sessionId == session.id && $0.isPR }.map { (ex.name, $0) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Erfolgssymbol
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 8) {
                    Text("Session beendet!")
                        .font(.largeTitle.bold())
                    Text("Gute Arbeit, Malik! Du hast heute ordentlich abgeliefert.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Statistiken
                HStack(spacing: 20) {
                    VStack {
                        Text("\(String(format: "%.0f", session.totalVolume(from: store)))")
                            .font(.title2.bold())
                        Text("Volume (kg)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    
                    VStack {
                        Text("\(sessionPRs.count)")
                            .font(.title2.bold())
                            .foregroundColor(.orange)
                        Text("Neue PRs 👑")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if !sessionPRs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Deine neuen Rekorde:")
                            .font(.headline)
                        
                        ForEach(sessionPRs, id: \.1.id) { pr in
                            HStack {
                                Text("👑")
                                Text(pr.0)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(String(format: "%.1f", pr.1.weight)) kg")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Fertig")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Zusammenfassung")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - EDIT SESSION

struct EditSessionView: View {
    
    let session: TrainingSession
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var notes = ""
    @State private var selectedExerciseIds: Set<UUID> = []
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return store.exercises
        } else {
            return store.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Session-Name") {
                    TextField("Name", text: $name)
                }
                
                Section("Übungen auswählen") {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            if selectedExerciseIds.contains(exercise.id) {
                                selectedExerciseIds.remove(exercise.id)
                            } else {
                                selectedExerciseIds.insert(exercise.id)
                            }
                        } label: {
                            HStack {
                                Text(exercise.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedExerciseIds.contains(exercise.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Session bearbeiten")
            .onAppear {
                name = session.name
                notes = session.notes
                selectedExerciseIds = Set(session.exerciseIds)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        store.updateSession(session, name: name, exerciseIds: Array(selectedExerciseIds), notes: notes)
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedExerciseIds.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Übung suchen")
        }
    }
}

// MARK: - ADD LOG TO SESSION (Mit Fortschritts-Vergleich)

struct AddLogToSessionView: View {
    
    let exercise: Exercise
    let sessionId: UUID
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight = ""
    @State private var reps = ""
    @State private var showPRCelebration = false
    
    var recommendation: (weight: Double, reps: Int)? {
        store.progressionRecommendation(for: exercise)
    }
    
    // Die letzten 4 Sätze absteigend sortiert
    var lastFourLogs: [WorkoutLog] {
        Array(exercise.logs.sorted(by: { $0.date > $1.date }).prefix(4))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Neue Daten") {
                    TextField(
                        "Gewicht (Vorschlag: \(String(format: "%.1f", recommendation?.weight ?? 0)) kg)", 
                        text: $weight
                    )
                    .keyboardType(.decimalPad)
                    .foregroundColor(weight.isEmpty ? .blue.opacity(0.6) : .primary)
                    
                    TextField(
                        "Wiederholungen (Vorschlag: \(recommendation?.reps ?? 0))", 
                        text: $reps
                    )
                    .keyboardType(.numberPad)
                    .foregroundColor(reps.isEmpty ? .blue.opacity(0.6) : .primary)
                }
                .listRowBackground(showPRCelebration ? Color.yellow.opacity(0.2) : nil)
                
                if let w = Double(weight.replacingOccurrences(of: ",", with: ".")), let r = Int(reps) {
                    Section("Vorschau") {
                        HStack {
                            Text("Volumen:")
                            Spacer()
                            Text("\(String(format: "%.0f", w * Double(r))) kg")
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                // Letzte Sätze am Ende der Form, klein und mit Vergleichswerten
                if !lastFourLogs.isEmpty {
                    Section("Letzte Referenzwerte") {
                        ForEach(Array(lastFourLogs.enumerated()), id: \.element.id) { index, log in
                            // Wir suchen den log davor für den Vergleich
                            let allSorted = exercise.logs.sorted(by: { $0.date > $1.date })
                            // Der "vorherige" Log im Sinne der Zeit ist der im Array nach dem aktuellen
                            let logIndex = allSorted.firstIndex(where: { $0.id == log.id }) ?? 0
                            let previousLog = (logIndex + 1 < allSorted.count) ? allSorted[logIndex + 1] : nil
                            
                            // Nutzung einer kompakten Version der Vergleichslogik
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(log.date.formattedString())
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    // Anzeige der Steigerung wie in der Übungsliste
                                    if let prev = previousLog {
                                        ComparisonBadge(current: log, previous: prev)
                                    }
                                }
                                
                                HStack {
                                    Text("\(String(format: "%.1f", log.weight)) kg × \(log.reps)")
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("Vol: \(String(format: "%.0f", log.volume)) kg")
                                        .font(.system(size: 10))
                                        .foregroundColor(.blue.opacity(0.8))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(exercise.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let w = Double(weight.replacingOccurrences(of: ",", with: ".")),
                           let r = Int(reps) {
                            
                            let isPR = store.checkPR(for: exercise, weight: w, reps: r)
                            
                            if isPR {
                                // Haptisches Feedback
                                let impact = UIImpactFeedbackGenerator(style: .heavy)
                                impact.impactOccurred()
                                
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showPRCelebration = true
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    store.addLog(to: exercise, weight: w, reps: r, sessionId: sessionId)
                                    dismiss()
                                }
                            } else {
                                store.addLog(to: exercise, weight: w, reps: r, sessionId: sessionId)
                                dismiss()
                            }
                        }
                    }
                    .disabled(weight.isEmpty || reps.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Hilfs-View für die kleinen Fortschrittsanzeigen (Badges)
struct ComparisonBadge: View {
    let current: WorkoutLog
    let previous: WorkoutLog
    
    var body: some View {
        HStack(spacing: 6) {
            let weightDiff = current.weight - previous.weight
            let repsDiff = current.reps - previous.reps
            
            if weightDiff != 0 {
                HStack(spacing: 1) {
                    Image(systemName: weightDiff > 0 ? "arrow.up" : "arrow.down")
                    Text("\(String(format: "%.1f", abs(weightDiff)))")
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(weightDiff > 0 ? .green : .red)
            }
            
            if repsDiff != 0 {
                HStack(spacing: 1) {
                    Image(systemName: repsDiff > 0 ? "arrow.up" : "arrow.down")
                    Text("\(abs(repsDiff))")
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(repsDiff > 0 ? .green : .red)
            }
        }
    }
}

// MARK: - ADD/EDIT PLAN

struct AddPlanView: View {
    
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    let planToEdit: TrainingPlan?
    @State private var name = ""
    @State private var notes = ""
    @State private var selectedExerciseIds: Set<UUID> = []
    
    init(planToEdit: TrainingPlan? = nil) {
        self.planToEdit = planToEdit
        _name = State(initialValue: planToEdit?.name ?? "")
        _notes = State(initialValue: planToEdit?.notes ?? "")
        _selectedExerciseIds = State(initialValue: Set(planToEdit?.exerciseIds ?? []))
    }
    
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return store.exercises
        } else {
            return store.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Plan-Name") {
                    TextField("z.B. Push/Pull/Legs", text: $name)
                }
                
                Section("Übungen auswählen") {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            if selectedExerciseIds.contains(exercise.id) {
                                selectedExerciseIds.remove(exercise.id)
                            } else {
                                selectedExerciseIds.insert(exercise.id)
                            }
                        } label: {
                            HStack {
                                Text(exercise.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedExerciseIds.contains(exercise.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle(planToEdit == nil ? "Neuer Plan" : "Plan bearbeiten")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(planToEdit == nil ? "Erstellen" : "Speichern") {
                        if let plan = planToEdit {
                            store.updatePlan(plan, name: name, exerciseIds: Array(selectedExerciseIds), notes: notes)
                        } else {
                            store.addPlan(name: name, exerciseIds: Array(selectedExerciseIds), notes: notes)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedExerciseIds.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Übung suchen")
        }
    }
}

// MARK: - PLAN DETAIL

struct PlanDetailView: View {
    
    let plan: TrainingPlan
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showStartSession = false
    @State private var showEditPlan = false
    
    var currentPlan: TrainingPlan? {
        store.plans.first { $0.id == plan.id }
    }
    
    var planExercises: [Exercise] {
        guard let p = currentPlan else { return [] }
        return store.exercises.filter { p.exerciseIds.contains($0.id) }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                if let p = currentPlan, !p.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beschreibung")
                            .font(.headline)
                        Text(p.notes)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Übungen (\(planExercises.count))")
                        .font(.headline)
                    
                    ForEach(planExercises) { exercise in
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            if let oneRM = exercise.estimatedOneRepMax {
                                Text("1RM: \(String(format: "%.1f", oneRM)) kg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Button {
                    showStartSession = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Session starten")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle(currentPlan?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditPlan = true
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    store.deletePlan(plan)
                    dismiss()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showStartSession) {
            if let p = currentPlan {
                StartSessionFromPlanView(plan: p)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showEditPlan) {
            if let p = currentPlan {
                AddPlanView(planToEdit: p)
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - START SESSION FROM PLAN

struct StartSessionFromPlanView: View {
    
    let plan: TrainingPlan
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var sessionName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Session-Name") {
                    TextField("z.B. \(plan.name) - Tag 1", text: $sessionName)
                }
                
                Section("Übungen") {
                    ForEach(store.exercises.filter { plan.exerciseIds.contains($0.id) }) { exercise in
                        Text(exercise.name)
                    }
                }
            }
            .navigationTitle("Session starten")
            .onAppear {
                sessionName = plan.name
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Starten") {
                        store.addSession(
                            name: sessionName,
                            exerciseIds: plan.exerciseIds,
                            notes: "Basierend auf Plan: \(plan.name)"
                        )
                        dismiss()
                    }
                    .disabled(sessionName.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: - SETTINGS VIEW

struct SettingsView: View {
    
    @EnvironmentObject var store: GymStore
    @EnvironmentObject var settings: SettingsStore
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: GymDataDocument?
    
    var body: some View {
        NavigationStack {
            List {
                // Darstellung
                Section("Darstellung") {
                    Picker("Design", selection: $settings.appearanceMode) {
                        Text("Automatisch").tag(nil as ColorScheme?)
                        Text("Hell").tag(ColorScheme.light as ColorScheme?)
                        Text("Dunkel").tag(ColorScheme.dark as ColorScheme?)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Einheiten
                Section("Einheiten") {
                    Picker("Gewichtseinheit", selection: $settings.weightUnit) {
                        ForEach(SettingsStore.WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.name).tag(unit)
                        }
                    }
                }
                
                // Anzeige
                Section("Anzeige") {
                    Toggle("Progressive Overload anzeigen", isOn: $settings.showProgressIndicators)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                // Training
                Section("Training") {
                    Stepper("Pause: \(settings.defaultRestTimer) Sek.", value: $settings.defaultRestTimer, in: 30...300, step: 15)
                }
                
                // Feedback
                Section("Feedback") {
                    Toggle("Töne", isOn: $settings.soundEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    Toggle("Haptisches Feedback", isOn: $settings.hapticFeedback)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                // Statistiken
                Section("Statistiken") {
                    HStack {
                        Text("Übungen")
                        Spacer()
                        Text("\(store.exercises.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Sessions")
                        Spacer()
                        Text("\(store.sessions.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Trainingspläne")
                        Spacer()
                        Text("\(store.plans.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Gesamte Logs")
                        Spacer()
                        Text("\(store.exercises.reduce(0) { $0 + $1.logs.count })")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Daten
                Section("Daten") {
                    Button {
                        exportDocument = GymDataDocument(backup: store.createBackup())
                        showExporter = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Datei exportieren (.json)")
                        }
                    }
                    
                    Button {
                        showImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Datei importieren (.json)")
                        }
                    }
                    
                    Button {
                        showExportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Text-Export (Legacy)")
                        }
                    }
                    
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Alle Daten löschen")
                        }
                    }
                }
                
                // Info
                Section("Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Entwickelt mit Leidenschaft")
                        }
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .alert("Alle Daten löschen?", isPresented: $showResetAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    store.clearAll()
                }
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle Übungen, Sessions und Pläne werden gelöscht.")
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "GymTrackerBackup.json"
            ) { result in }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url),
                           let backup = try? JSONDecoder().decode(GymDataBackup.self, from: data) {
                            store.restore(from: backup)
                        }
                    }
                case .failure(let error):
                    print("Import failed: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportDataView()
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - EXPORT DATA VIEW

struct ExportDataView: View {
    
    @EnvironmentObject var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @State private var exportText = ""
    @State private var showCopiedAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Daten exportieren")
                    .font(.headline)
                    .padding(.top)
                
                Text("Kopiere den folgenden Text und speichere ihn sicher. Du kannst ihn später verwenden, um deine Daten wiederherzustellen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                ScrollView {
                    Text(exportText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                
                Button {
                    UIPasteboard.general.string = exportText
                    showCopiedAlert = true
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("In Zwischenablage kopieren")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateExportData()
            }
            .alert("Kopiert!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Die Daten wurden in die Zwischenablage kopiert.")
            }
        }
    }
    
    private func generateExportData() {
        let data: [String: Any] = [
            "exercises": (try? JSONEncoder().encode(store.exercises))?.base64EncodedString() ?? "",
            "sessions": (try? JSONEncoder().encode(store.sessions))?.base64EncodedString() ?? "",
            "plans": (try? JSONEncoder().encode(store.plans))?.base64EncodedString() ?? "",
            "version": "1.0"
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            exportText = jsonString
        }
    }
}


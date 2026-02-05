import Combine
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]) private var sessions: [WorkoutSession]
    @Query(sort: [SortDescriptor(\RoutineTemplate.name)]) private var templates: [RoutineTemplate]

    @State private var currentSessionID: UUID?
    @State private var didSeedTemplates = false
    @State private var summaryMessage: String?

    private var activeSession: WorkoutSession? {
        sessions.first(where: { $0.isActive })
    }

    private var currentSession: WorkoutSession? {
        if let currentSessionID,
           let session = sessions.first(where: { $0.id == currentSessionID }) {
            return session
        }
        return nil
    }

    private var weeklyStartCount: Int {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) else {
            return 0
        }
        return sessions.filter { $0.startedAt >= weekAgo }.count
    }

    private var isSummaryPresented: Binding<Bool> {
        Binding(
            get: { summaryMessage != nil },
            set: { isPresented in
                if !isPresented {
                    summaryMessage = nil
                }
            }
        )
    }

    var body: some View {
        Group {
            if let currentSession {
                WorkoutSessionView(
                    session: currentSession,
                    allSessions: sessions,
                    onEnd: { summaryLines in
                        currentSessionID = nil
                        summaryMessage = summaryLines.joined(separator: "\n")
                    }
                )
            } else {
                HomeView(
                    hasActiveSession: activeSession != nil,
                    weeklyStartCount: weeklyStartCount,
                    onPrimaryTap: handlePrimaryTap
                )
            }
        }
        .onAppear(perform: seedTemplatesIfNeeded)
        .alert("Workout Summary", isPresented: isSummaryPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(summaryMessage ?? "")
        }
        // Force dark mode for the premium look
        .preferredColorScheme(.dark)
    }

    private func handlePrimaryTap() {
        if let activeSession {
            currentSessionID = activeSession.id
            return
        }
        startWorkoutSession()
    }

    private func startWorkoutSession() {
        guard let selectedTemplate = preferredTemplate() else { return }

        let newSession = WorkoutSession(routineName: selectedTemplate.name)
        modelContext.insert(newSession)

        for exercise in selectedTemplate.orderedExercises {
            let exerciseLog = ExerciseLog(name: exercise.name, order: exercise.order)
            modelContext.insert(exerciseLog)
            newSession.exerciseLogs.append(exerciseLog)
        }

        persistContextIfPossible()
        currentSessionID = newSession.id
    }

    private func preferredTemplate() -> RoutineTemplate? {
        if templates.isEmpty {
            seedTemplatesIfNeeded()
        }

        if let aTemplate = templates.first(where: { $0.name.contains("A") }) {
            return aTemplate
        }
        return templates.first
    }

    private func seedTemplatesIfNeeded() {
        guard !didSeedTemplates else { return }
        didSeedTemplates = true

        guard templates.isEmpty else { return }
        createTemplate(name: "A Routine", exercises: ["Squat", "Bench Press", "Barbell Row"])
        createTemplate(name: "B Routine", exercises: ["Deadlift", "Overhead Press", "Lat Pulldown"])
        persistContextIfPossible()
    }

    private func createTemplate(name: String, exercises: [String]) {
        let template = RoutineTemplate(name: name)
        modelContext.insert(template)

        for (index, exerciseName) in exercises.enumerated() {
            let routineExercise = RoutineExercise(name: exerciseName, order: index)
            modelContext.insert(routineExercise)
            template.exercises.append(routineExercise)
        }
    }

    private func persistContextIfPossible() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save SwiftData context: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                WorkoutSession.self,
                ExerciseLog.self,
                SetLog.self,
                RoutineTemplate.self,
                RoutineExercise.self
            ],
            inMemory: true
        )
}

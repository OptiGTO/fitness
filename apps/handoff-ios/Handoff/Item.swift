import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var routineName: String
    var startedAt: Date
    var endedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    var exerciseLogs: [ExerciseLog]

    init(
        id: UUID = UUID(),
        routineName: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        exerciseLogs: [ExerciseLog] = []
    ) {
        self.id = id
        self.routineName = routineName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exerciseLogs = exerciseLogs
    }
}

@Model
final class ExerciseLog {
    @Attribute(.unique) var id: UUID
    var name: String
    var order: Int
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog)
    var sets: [SetLog]

    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        session: WorkoutSession? = nil,
        sets: [SetLog] = []
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.session = session
        self.sets = sets
    }
}

@Model
final class SetLog {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var weight: Double
    var reps: Int
    var rpe: Double
    var memo: String
    var exerciseLog: ExerciseLog?

    init(
        id: UUID = UUID(),
        completedAt: Date = .now,
        weight: Double,
        reps: Int,
        rpe: Double = 8,
        memo: String = "",
        exerciseLog: ExerciseLog? = nil
    ) {
        self.id = id
        self.completedAt = completedAt
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.memo = memo
        self.exerciseLog = exerciseLog
    }
}

@Model
final class RoutineTemplate {
    @Attribute(.unique) var id: UUID
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.template)
    var exercises: [RoutineExercise]

    init(id: UUID = UUID(), name: String, exercises: [RoutineExercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

@Model
final class RoutineExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var order: Int
    var template: RoutineTemplate?

    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        template: RoutineTemplate? = nil
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.template = template
    }
}

extension WorkoutSession {
    var orderedExercises: [ExerciseLog] {
        exerciseLogs.sorted { $0.order < $1.order }
    }

    var isActive: Bool {
        endedAt == nil
    }
}

extension ExerciseLog {
    var orderedSets: [SetLog] {
        sets.sorted { $0.completedAt < $1.completedAt }
    }
}

extension RoutineTemplate {
    var orderedExercises: [RoutineExercise] {
        exercises.sorted { $0.order < $1.order }
    }
}

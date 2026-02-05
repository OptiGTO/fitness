//
//  HandoffApp.swift
//  Handoff
//
//  Created by 우민주 on 2/5/26.
//

import SwiftUI
import SwiftData

@main
struct HandoffApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            ExerciseLog.self,
            SetLog.self,
            RoutineTemplate.self,
            RoutineExercise.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

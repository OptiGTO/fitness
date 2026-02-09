import SwiftUI
import SwiftData
import Combine

struct WorkoutSessionView: View {
    private enum SessionMode {
        case workout
        case rest
    }

    @Environment(\.modelContext) private var modelContext
    
    let session: WorkoutSession
    let allSessions: [WorkoutSession]
    let onEnd: ([String]) -> Void
    
    @State private var pendingWeight = 20.0
    @State private var pendingReps = 10
    @State private var pendingRPE = 8.0
    @State private var pendingMemo = ""
    @State private var restEndsAt: Date?
    @State private var restRemainingSeconds = 0
    @State private var isAdjustSheetPresented = false
    @State private var didPrepareAutofill = false
    @State private var sessionMode: SessionMode = .workout
    
    // Timer
    private let restDurationSeconds = 90
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var currentExercise: ExerciseLog? {
        session.orderedExercises.first
    }
    
    private var orderedSets: [SetLog] {
        currentExercise?.orderedSets ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top Bar
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text(session.routineName.uppercased())
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.textSecondary)
                        .kerning(1)
                    
                    Text(currentExercise?.name ?? "No Exercise")
                        .font(Theme.Fonts.display(24))
                        .foregroundStyle(Theme.textPrimary)
                }
                
                Spacer()
                
                Button(action: endWorkout) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.top, 10)
            
            if sessionMode == .workout {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. AI Suggestion / Current Target
                        suggestionCard
                        
                        // 2. History
                        if !orderedSets.isEmpty {
                            historyView
                        }
                    }
                }
                
                Spacer()
                
                workoutActionArea
            } else {
                Spacer()
                restModeArea
                Spacer()
            }
        }
        .padding(Theme.Layout.padding)
        .appBackground()
        .onAppear {
            if !didPrepareAutofill {
                prepareAutofill()
                didPrepareAutofill = true
            }
        }
        .onReceive(timer) { _ in
            tickRestTimer()
        }
        .sheet(isPresented: $isAdjustSheetPresented) {
            adjustSheet
        }
    }
    
    // MARK: - Subviews
    
    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.accent)
                Text("AI Insight")
                    .font(Theme.Fonts.headline(14))
                    .foregroundStyle(Theme.accent)
                Spacer()
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(formatWeight(pendingWeight))")
                    .font(Theme.Fonts.number(48))
                    .foregroundStyle(Theme.textPrimary)
                Text("kg")
                    .font(Theme.Fonts.body(20))
                    .foregroundStyle(Theme.textSecondary)
                
                Text("×")
                    .font(Theme.Fonts.body(24))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                
                Text("\(pendingReps)")
                    .font(Theme.Fonts.number(48))
                    .foregroundStyle(Theme.textPrimary)
                Text("reps")
                    .font(Theme.Fonts.body(20))
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Text("Keep current pace. Motion velocity is consistent.")
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .premiumCard()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var restTimerView: some View {
        VStack(spacing: 8) {
            Text("휴식 타이머")
                .font(Theme.Fonts.headline(16))
                .foregroundStyle(Theme.textSecondary)
            Text("\(restRemainingSeconds)s")
                .font(Theme.Fonts.number(56))
                .foregroundStyle(Theme.secondaryAccent)
        }
        .padding(20)
        .premiumCard()
    }

    private var workoutActionArea: some View {
        VStack(spacing: 12) {
            Button(action: completeSet) {
                Text("Complete Set")
                    .font(Theme.Fonts.headline(20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Theme.accent)
                    .foregroundStyle(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded(adjustWithSwipe))
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                    isAdjustSheetPresented = true
                }
            )

            Text("Swipe to Adjust • Hold for RPE")
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var restModeArea: some View {
        VStack(spacing: 20) {
            restTimerView

            Button(action: startNewSet) {
                Text("새 세트 시작")
                    .font(Theme.Fonts.headline(20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Theme.secondaryAccent)
                    .foregroundStyle(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
    
    private var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set Log")
                .font(Theme.Fonts.headline(16))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)
            
            VStack(spacing: 8) {
                ForEach(orderedSets.reversed()) { set in
                    HStack {
                        Text("\(formatWeight(set.weight))kg × \(set.reps)")
                            .font(Theme.Fonts.number(16))
                            .foregroundStyle(Theme.textPrimary)
                        
                        Spacer()
                        
                        Text("RPE \(String(format: "%.1f", set.rpe))")
                            .font(Theme.Fonts.body(14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(16)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var adjustSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $pendingWeight, in: 0...500, step: 2.5) {
                        HStack {
                            Text("Weight")
                            Spacer()
                            Text("\(formatWeight(pendingWeight)) kg")
                                .font(.body.monospacedDigit())
                        }
                    }
                    
                    Stepper(value: $pendingReps, in: 1...100) {
                        HStack {
                            Text("Reps")
                            Spacer()
                            Text("\(pendingReps)")
                                .font(.body.monospacedDigit())
                        }
                    }
                    
                    Stepper(value: $pendingRPE, in: 1...10, step: 0.5) {
                        HStack {
                            Text("RPE")
                            Spacer()
                            Text(String(format: "%.1f", pendingRPE))
                                .font(.body.monospacedDigit())
                        }
                    }
                } header: {
                    Text("Targets")
                }
                
                Section {
                    TextField("Notes", text: $pendingMemo, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Memo")
                }
            }
            .navigationTitle("Adjust Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isAdjustSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Logic Methods
    
    private func completeSet() {
        guard sessionMode == .workout else { return }
        guard let currentExercise else { return }
        
        let setLog = SetLog(
            completedAt: .now,
            weight: pendingWeight,
            reps: pendingReps,
            rpe: pendingRPE,
            memo: pendingMemo.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        modelContext.insert(setLog)
        currentExercise.sets.append(setLog)
        pendingMemo = ""
        startRestTimer()
        prepareAutofill()
        persistContextIfPossible()
    }
    
    private func startRestTimer() {
        restEndsAt = Date().addingTimeInterval(Double(restDurationSeconds))
        restRemainingSeconds = restDurationSeconds
        sessionMode = .rest
    }

    private func startNewSet() {
        restEndsAt = nil
        restRemainingSeconds = 0
        sessionMode = .workout
    }
    
    private func tickRestTimer() {
        guard let restEndsAt else { return }
        let remaining = Int(ceil(restEndsAt.timeIntervalSinceNow))
        if remaining <= 0 {
            restRemainingSeconds = 0
            self.restEndsAt = nil
            return
        }
        restRemainingSeconds = remaining
    }
    
    private func adjustWithSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        
        if abs(horizontal) >= abs(vertical) {
            if horizontal > 24 {
                pendingWeight += 2.5
            } else if horizontal < -24 {
                pendingWeight = max(0, pendingWeight - 2.5)
            }
            return
        }
        
        if vertical < -24 {
            pendingReps += 1
        } else if vertical > 24 {
            pendingReps = max(1, pendingReps - 1)
        }
    }
    
    private func prepareAutofill() {
        guard let currentExercise else { return }
        
        if let lastSet = currentExercise.orderedSets.last {
            pendingWeight = lastSet.weight
            pendingReps = lastSet.reps
            pendingRPE = lastSet.rpe
            return
        }
        
        if let previousSet = latestHistoricalSet(for: currentExercise.name) {
            pendingWeight = previousSet.weight
            pendingReps = previousSet.reps
            pendingRPE = previousSet.rpe
            return
        }
        
        pendingWeight = 20
        pendingReps = 10
        pendingRPE = 8
    }
    
    private func latestHistoricalSet(for exerciseName: String) -> SetLog? {
        for historicalSession in allSessions where historicalSession.id != session.id && !historicalSession.isActive {
            if let matchedExercise = historicalSession.orderedExercises.first(where: { $0.name == exerciseName }),
               let lastSet = matchedExercise.orderedSets.last {
                return lastSet
            }
        }
        return nil
    }
    
    private func endWorkout() {
        session.endedAt = .now
        persistContextIfPossible()
        onEnd(summaryLines())
    }
    
    private func summaryLines() -> [String] {
        let allSets = session.orderedExercises.flatMap(\.orderedSets)
        let totalVolume = allSets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        let bestSet = allSets.max { lhs, rhs in
            (lhs.weight * Double(lhs.reps)) < (rhs.weight * Double(rhs.reps))
        }

        let line1 = "Total \(allSets.count) sets, Volume \(String(format: "%.0f", totalVolume))kg"
        let line2: String
        if let bestSet {
            line2 = "Best: \(formatWeight(bestSet.weight))kg × \(bestSet.reps)"
        } else {
            line2 = "Best: N/A"
        }
        
        // This logic is simple/naive for now
        let line3 = "Great job! Rest well."
        return [line1, line2, line3]
    }
    
    private func persistContextIfPossible() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save SwiftData context: \(error.localizedDescription)")
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }
}

#Preview {
    WorkoutSessionView(
        session: WorkoutSession(routineName: "A Routine"),
        allSessions: [],
        onEnd: { _ in }
    )
    .modelContainer(for: [WorkoutSession.self, ExerciseLog.self, SetLog.self, RoutineTemplate.self, RoutineExercise.self], inMemory: true)
}

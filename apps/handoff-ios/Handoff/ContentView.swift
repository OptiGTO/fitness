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
        .padding()
        .onAppear(perform: seedTemplatesIfNeeded)
        .alert("오늘 운동 요약", isPresented: isSummaryPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(summaryMessage ?? "")
        }
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
        createTemplate(name: "A 루틴", exercises: ["스쿼트", "벤치 프레스", "바벨 로우"])
        createTemplate(name: "B 루틴", exercises: ["데드리프트", "오버헤드 프레스", "랫 풀다운"])
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

private struct HomeView: View {
    let hasActiveSession: Bool
    let weeklyStartCount: Int
    let onPrimaryTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("오늘 운동")
                .font(.largeTitle.bold())

            Text(hasActiveSession ? "진행 중인 세션이 있어요." : "버튼 한 번으로 시작해요.")
                .foregroundStyle(.secondary)

            Text("최근 7일 시작 횟수: \(weeklyStartCount)회")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onPrimaryTap) {
                    Text(hasActiveSession ? "이어하기" : "시작")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
                .buttonStyle(.borderedProminent)

                Text("스와이프: 무게/횟수 조정 · 롱프레스: RPE/메모")
                    .font(.footnote)
                    .hidden()

                Text("운동 종료")
                    .font(.footnote)
                    .hidden()
            }
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WorkoutSessionView: View {
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

    private let restDurationSeconds = 90
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentExercise: ExerciseLog? {
        session.orderedExercises.first
    }

    private var orderedSets: [SetLog] {
        currentExercise?.orderedSets ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.routineName)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("운동 종료", role: .destructive, action: endWorkout)
                    .font(.footnote)
            }

            Text(currentExercise?.name ?? "운동이 없습니다")
                .font(.largeTitle.bold())

            suggestionCard

            if restRemainingSeconds > 0 {
                Text("휴식 \(restRemainingSeconds)초")
                    .font(.title3.bold())
            } else {
                Text("휴식 완료. 바로 다음 세트로 진행해요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !orderedSets.isEmpty {
                Text("최근 세트")
                    .font(.headline)

                ForEach(orderedSets.suffix(3).reversed()) { set in
                    Text("\(formatWeight(set.weight))kg × \(set.reps) · RPE \(String(format: "%.1f", set.rpe))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: completeSet) {
                    Text("세트 완료")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 90)
                }
                .buttonStyle(.borderedProminent)
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded(adjustWithSwipe))
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                        isAdjustSheetPresented = true
                    }
                )

                Text("스와이프: 무게/횟수 조정 · 롱프레스: RPE/메모")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("운동 종료")
                    .font(.footnote)
                    .hidden()
            }
            .padding(.bottom, 14)
        }
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
            NavigationStack {
                Form {
                    Stepper(
                        value: $pendingWeight,
                        in: 0.0...500.0,
                        step: 2.5
                    ) {
                        Text("무게: \(formatWeight(pendingWeight))kg")
                    }

                    Stepper(value: $pendingReps, in: 1...30) {
                        Text("횟수: \(pendingReps)")
                    }

                    Stepper(
                        value: $pendingRPE,
                        in: 1.0...10.0,
                        step: 0.5
                    ) {
                        Text("RPE: \(String(format: "%.1f", pendingRPE))")
                    }

                    TextField("메모", text: $pendingMemo)
                }
                .navigationTitle("미세 조정")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") {
                            isAdjustSheetPresented = false
                        }
                    }
                }
            }
        }
    }

    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("다음 세트 자동 채움")
                .font(.headline)
            Text("\(formatWeight(pendingWeight))kg × \(pendingReps)")
                .font(.title2.bold())
            Text("AI 한 줄(초안): 현재 페이스 유지, 동작 속도 일정하게 진행")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func completeSet() {
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

        let line1 = "총 \(allSets.count)세트, 볼륨 \(String(format: "%.0f", totalVolume))kg"
        let line2: String
        if let bestSet {
            line2 = "최고 세트: \(formatWeight(bestSet.weight))kg × \(bestSet.reps)"
        } else {
            line2 = "최고 세트: 기록 없음"
        }

        let line3: String
        if let lastSet = allSets.last {
            let nextWeight = lastSet.reps >= 8 ? lastSet.weight + 2.5 : lastSet.weight
            line3 = "다음 목표: \(formatWeight(nextWeight))kg × \(max(6, lastSet.reps))"
        } else {
            line3 = "다음 목표: 20kg × 10으로 시작"
        }
        return [line1, line2, line3]
    }

    private func persistContextIfPossible() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save SwiftData context: \(error.localizedDescription)")
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

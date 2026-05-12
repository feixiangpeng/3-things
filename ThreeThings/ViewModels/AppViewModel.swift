import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var plan: DailyPlan
    @Published var selectedInputMode: InputMode = .text
    @Published var pendingFinalizationDayID: String?
    @Published var momentum7: Int = 0
    @Published var extractionStatus: String = ""
    @Published var isExtracting: Bool = false
    @Published var voiceDraft: VoiceExtractionDraft?
    @Published var selectedVoiceFixtureID: String = MockVoiceDraftProvider.fixtures[2].id

    private struct StoredState: Codable {
        var plan: DailyPlan?
        var momentumOutcomes: [String: Bool]
        var lastFinalizedFocusDayID: String?
        var pendingFinalizationDayID: String?
    }

    private let storageKey = "three_things.v1.state"
    private let defaults: UserDefaults
    private let voiceDraftExtractor: any VoiceDraftExtracting
    private let mockVoiceDraftProvider: MockVoiceDraftProvider
    private let dateProvider: () -> Date

    private var momentumOutcomes: [String: Bool] = [:]
    private var lastFinalizedFocusDayID: String?

    init(
        defaults: UserDefaults = .standard,
        voiceDraftExtractor: (any VoiceDraftExtracting)? = nil,
        mockVoiceDraftProvider: MockVoiceDraftProvider = MockVoiceDraftProvider(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.voiceDraftExtractor = voiceDraftExtractor ?? AppVoiceDraftExtractorFactory.default()
        self.mockVoiceDraftProvider = mockVoiceDraftProvider
        self.dateProvider = dateProvider
        self.plan = DailyPlan.empty(for: FocusDay.id(for: dateProvider()))

        loadState()
        bootstrapForCurrentFocusDay()
        recomputeMomentum()
        saveState()
    }

    var progressText: String {
        if plan.isLocked {
            return "\(completedTaskCount)/\(lockedTaskCount) done"
        }
        return "\(draftTaskCount)/3 selected"
    }

    var completedTaskCount: Int {
        plan.tasks.filter { $0.isCompleted }.count
    }

    var draftTaskCount: Int {
        plan.tasks.reduce(into: 0) { count, item in
            if !normalized(item.text).isEmpty {
                count += 1
            }
        }
    }

    var lockedTaskCount: Int {
        max(plan.tasks.count, 1)
    }

    var duplicateTaskIndexes: Set<Int> {
        var firstIndexByText: [String: Int] = [:]
        var duplicates = Set<Int>()

        for (index, item) in plan.tasks.enumerated() {
            let key = duplicateKey(for: item.text)
            guard !key.isEmpty else { continue }

            if let firstIndex = firstIndexByText[key] {
                duplicates.insert(firstIndex)
                duplicates.insert(index)
            } else {
                firstIndexByText[key] = index
            }
        }

        return duplicates
    }

    var taskValidationMessage: String? {
        guard !plan.isLocked else { return nil }

        let nonEmptyCount = draftTaskCount
        if nonEmptyCount == 0 {
            return "Choose at least 1 thing."
        }

        if nonEmptyCount > 3 {
            return "Choose no more than 3 things."
        }

        if plan.tasks.contains(where: { normalized($0.text).count > 100 }) {
            return "Each thing must be 100 characters or fewer."
        }

        if !duplicateTaskIndexes.isEmpty {
            return "Each thing needs to be distinct."
        }

        return nil
    }

    var canLockPlan: Bool {
        canPresentLockConfirmation
    }

    var canPresentLockConfirmation: Bool {
        guard !plan.isLocked else { return false }

        let nonEmptyCount = draftTaskCount
        guard (1...3).contains(nonEmptyCount) else { return false }

        guard plan.tasks.allSatisfy({ item in
            let text = normalized(item.text)
            return text.count <= 100
        }) else { return false }

        return duplicateTaskIndexes.isEmpty
    }

    var canEditPlan: Bool {
        !plan.isLocked
    }

    var voiceFixtures: [MockVoiceDraftFixture] {
        MockVoiceDraftProvider.fixtures
    }

    var selectedVoiceFixture: MockVoiceDraftFixture {
        mockVoiceDraftProvider.fixture(withID: selectedVoiceFixtureID)
    }

    func characterCount(at index: Int) -> Int {
        guard plan.tasks.indices.contains(index) else { return 0 }
        return normalized(plan.tasks[index].text).count
    }

    func updateTaskText(at index: Int, text: String) {
        guard canEditPlan, plan.tasks.indices.contains(index) else { return }

        let clamped = String(text.prefix(100))
        plan.tasks[index].text = clamped
        syncVoiceDraftFromPlan()
        recomputeMomentum()
        saveState()
    }

    func moveTask(from sourceIndex: Int, to destinationIndex: Int) {
        guard canEditPlan,
              plan.tasks.indices.contains(sourceIndex),
              plan.tasks.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else {
            return
        }

        let item = plan.tasks.remove(at: sourceIndex)
        plan.tasks.insert(item, at: destinationIndex)
        normalizeDraftSortOrder()
        syncVoiceDraftFromPlan()
        saveState()
    }

    func confirmLockPlan() {
        guard canPresentLockConfirmation else { return }

        let lockedTasks = plan.tasks
            .map { item -> TaskItem in
                var nextItem = item
                nextItem.text = normalized(nextItem.text)
                nextItem.isCompleted = false
                return nextItem
            }
            .filter { !$0.text.isEmpty }
            .prefix(3)
            .enumerated()
            .map { index, item in
                var nextItem = item
                nextItem.sortOrder = index
                return nextItem
            }

        plan.tasks = Array(lockedTasks)

        if voiceDraft == nil {
            plan.source = .text
        }
        plan.isLocked = true
        recomputeMomentum()
        saveState()
    }

    func lockPlanFromText() {
        confirmLockPlan()
    }

    func toggleCompletion(taskID: UUID) {
        guard plan.isLocked,
              let index = plan.tasks.firstIndex(where: { $0.id == taskID }) else {
            return
        }

        plan.tasks[index].isCompleted.toggle()
        recomputeMomentum()
        saveState()
    }

    func finalizePendingDay(completed: Bool) {
        guard let pendingID = pendingFinalizationDayID else { return }

        momentumOutcomes[pendingID] = completed
        lastFinalizedFocusDayID = pendingID
        pendingFinalizationDayID = nil

        recomputeMomentum()
        saveState()
    }

    func startVoiceDraftReview(from draft: VoiceExtractionDraft) {
        guard canEditPlan else { return }

        let normalizedSelected = cappedTasks(from: draft.selectedTasks, fillToThree: true)
        let normalizedExtras = cappedTasks(from: draft.extraCandidates, fillToThree: false)
        let nextDraft = VoiceExtractionDraft(
            selectedTasks: Array(normalizedSelected.prefix(3)),
            extraCandidates: normalizedExtras,
            detectedMoreThanThree: draft.detectedMoreThanThree || !normalizedExtras.isEmpty,
            cleanedTranscript: normalized(draft.cleanedTranscript)
        )

        voiceDraft = nextDraft
        plan.source = .voice
        plan.extras = nextDraft.extraCandidates
        plan.detectedMoreThanThree = nextDraft.detectedMoreThanThree

        for index in plan.tasks.indices {
            plan.tasks[index].text = index < normalizedSelected.count ? normalizedSelected[index] : ""
            plan.tasks[index].isCompleted = false
            plan.tasks[index].sortOrder = index
        }

        selectedInputMode = .voice
        recomputeMomentum()
        saveState()
    }

    func generateMockVoiceDraft() {
        let fixture = selectedVoiceFixture
        startVoiceDraftReview(from: fixture.draft)
        extractionStatus = "Drafted from \(fixture.title)."
    }

    func replaceSelectedTask(at selectedIndex: Int, withExtraAt extraIndex: Int) {
        guard canEditPlan,
              plan.tasks.indices.contains(selectedIndex),
              plan.extras.indices.contains(extraIndex) else {
            return
        }

        let extra = plan.extras.remove(at: extraIndex)
        let currentText = normalized(plan.tasks[selectedIndex].text)
        plan.tasks[selectedIndex].text = extra
        if !currentText.isEmpty {
            plan.extras.append(currentText)
        }
        syncVoiceDraftFromPlan()
        saveState()
    }

    func updateExtraCandidate(at index: Int, text: String) {
        guard canEditPlan, plan.extras.indices.contains(index) else { return }

        plan.extras[index] = normalized(String(text.prefix(100)))
        syncVoiceDraftFromPlan()
        saveState()
    }

    func discardExtraCandidate(at index: Int) {
        guard canEditPlan, plan.extras.indices.contains(index) else { return }

        plan.extras.remove(at: index)
        syncVoiceDraftFromPlan()
        saveState()
    }

    func returnToTextEntry() {
        guard canEditPlan else { return }

        voiceDraft = nil
        plan = DailyPlan.empty(for: plan.focusDayID)
        selectedInputMode = .text
        extractionStatus = ""
        recomputeMomentum()
        saveState()
    }

    func resetExtractionStatus() {
        extractionStatus = ""
    }

    func extractTasksFromTranscript(_ transcript: String) async {
        guard canEditPlan else {
            extractionStatus = "Tasks are already locked for today."
            return
        }

        let cleanTranscript = normalized(transcript)
        guard !cleanTranscript.isEmpty else {
            extractionStatus = "Add or record transcript text first."
            return
        }

        isExtracting = true
        defer { isExtracting = false }

        do {
            let draft = try await voiceDraftExtractor.extractDraft(from: cleanTranscript)
            startVoiceDraftReview(from: draft)
            extractionStatus = "Drafted tasks from \(voiceDraftExtractor.providerName). Review and lock."
        } catch {
            voiceDraft = nil
            plan = DailyPlan.empty(for: plan.focusDayID)
            selectedInputMode = .text
            extractionStatus = "\(error.localizedDescription) Type instead."
        }

        recomputeMomentum()
        saveState()
    }

    private func bootstrapForCurrentFocusDay() {
        let currentFocusDayID = FocusDay.id(for: dateProvider())

        if plan.focusDayID != currentFocusDayID {
            handleFocusDayRollover(from: plan)
            plan = DailyPlan.empty(for: currentFocusDayID)
            selectedInputMode = .text
            voiceDraft = nil
        }

        pruneMomentumWindow()
    }

    private func handleFocusDayRollover(from previousPlan: DailyPlan) {
        guard previousPlan.isLocked else { return }

        if !previousPlan.tasks.isEmpty && previousPlan.tasks.allSatisfy({ $0.isCompleted }) {
            momentumOutcomes[previousPlan.focusDayID] = true
            lastFinalizedFocusDayID = previousPlan.focusDayID
        } else if pendingFinalizationDayID == nil {
            pendingFinalizationDayID = previousPlan.focusDayID
        }
    }

    private func pruneMomentumWindow() {
        let validIDs = Set(FocusDay.trailingIDs(count: 7, endingAt: dateProvider()))
        momentumOutcomes = momentumOutcomes.filter { validIDs.contains($0.key) }
    }

    private func recomputeMomentum() {
        let trailingIDs = FocusDay.trailingIDs(count: 7, endingAt: dateProvider())

        momentum7 = trailingIDs.reduce(into: 0) { count, focusDayID in
            if focusDayID == plan.focusDayID,
               plan.isLocked,
               !plan.tasks.isEmpty,
               plan.tasks.allSatisfy({ $0.isCompleted }) {
                count += 1
                return
            }

            if momentumOutcomes[focusDayID] == true {
                count += 1
            }
        }
    }

    private func loadState() {
        guard let data = defaults.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(StoredState.self, from: data) else {
            return
        }

        if let storedPlan = state.plan {
            plan = storedPlan
        }

        momentumOutcomes = state.momentumOutcomes
        lastFinalizedFocusDayID = state.lastFinalizedFocusDayID
        pendingFinalizationDayID = state.pendingFinalizationDayID
    }

    private func saveState() {
        let state = StoredState(
            plan: plan,
            momentumOutcomes: momentumOutcomes,
            lastFinalizedFocusDayID: lastFinalizedFocusDayID,
            pendingFinalizationDayID: pendingFinalizationDayID
        )

        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func duplicateKey(for value: String) -> String {
        normalized(value).lowercased()
    }

    private func normalizeDraftSortOrder() {
        for index in plan.tasks.indices {
            plan.tasks[index].sortOrder = index
        }
    }

    private func cappedTasks(from values: [String], fillToThree: Bool) -> [String] {
        var tasks = values
            .map { normalized(String($0.prefix(100))) }
            .filter { !$0.isEmpty }

        if fillToThree {
            tasks = Array(tasks.prefix(3))
            while tasks.count < 3 {
                tasks.append("")
            }
        }

        return tasks
    }

    private func syncVoiceDraftFromPlan() {
        guard let voiceDraft else { return }

        self.voiceDraft = VoiceExtractionDraft(
            selectedTasks: plan.tasks.map(\.text).filter { !normalized($0).isEmpty },
            extraCandidates: plan.extras,
            detectedMoreThanThree: !plan.extras.isEmpty || plan.detectedMoreThanThree,
            cleanedTranscript: voiceDraft.cleanedTranscript
        )
        plan.detectedMoreThanThree = self.voiceDraft?.detectedMoreThanThree ?? false
    }
}

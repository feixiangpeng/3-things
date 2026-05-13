import XCTest
@testable import ThreeThings

@MainActor
final class LiveVoiceExtractionTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LiveVoiceExtractionTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDebouncedLiveExtractionRunsAfterDelay() async throws {
        let extractor = CountingHeuristicExtractor()
        let viewModel = AppViewModel(
            defaults: defaults,
            voiceDraftExtractor: extractor,
            liveExtractionDebounceNanoseconds: 80_000_000
        )
        viewModel.selectedInputMode = .voice

        viewModel.updateVoiceTranscriptSnapshot("one, two, three, four, five, six, seven, eight")

        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(extractor.callCount, 1)
        XCTAssertNotNil(viewModel.voiceDraft)
    }

    func testRapidTranscriptChangesCancelEarlierExtraction() async throws {
        let extractor = CountingHeuristicExtractor()
        let viewModel = AppViewModel(
            defaults: defaults,
            voiceDraftExtractor: extractor,
            liveExtractionDebounceNanoseconds: 120_000_000
        )
        viewModel.selectedInputMode = .voice

        viewModel.updateVoiceTranscriptSnapshot("alpha, beta, gamma, delta, epsilon, zeta, eta, theta")
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.updateVoiceTranscriptSnapshot("one, two, three, four, five, six, seven, eight")
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(extractor.callCount, 1)
        XCTAssertEqual(extractor.lastTranscript?.contains("one"), true)
    }

    func testUserEditsPauseLiveExtractionUntilResync() async throws {
        let extractor = CountingHeuristicExtractor()
        let viewModel = AppViewModel(
            defaults: defaults,
            voiceDraftExtractor: extractor,
            liveExtractionDebounceNanoseconds: 80_000_000
        )
        viewModel.selectedInputMode = .voice

        viewModel.updateVoiceTranscriptSnapshot("one, two, three, four, five, six, seven, eight")
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(extractor.callCount, 1)

        viewModel.updateTaskText(at: 0, text: "Manual override")
        extractor.callCount = 0

        viewModel.updateVoiceTranscriptSnapshot("nine, eight, seven, six, five, four, three, two")
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(extractor.callCount, 0)

        await viewModel.applyLatestVoiceResync()
        XCTAssertGreaterThanOrEqual(extractor.callCount, 1)
    }

    func testStaleFlushResultIgnoredWhenTranscriptAdvances() async throws {
        let extractor = SlowHeuristicExtractor(delayNanoseconds: 200_000_000)
        let viewModel = AppViewModel(
            defaults: defaults,
            voiceDraftExtractor: extractor,
            liveExtractionDebounceNanoseconds: 50_000_000
        )
        viewModel.selectedInputMode = .voice

        async let flushDone: Void = viewModel.flushLiveExtractionNow(
            transcript: "first, second, third, fourth, fifth, sixth, seventh, eighth"
        )
        try await Task.sleep(nanoseconds: 30_000_000)
        viewModel.updateVoiceTranscriptSnapshot("nine, ten, eleven, twelve, thirteen, fourteen, fifteen, sixteen")
        await flushDone
        try await Task.sleep(nanoseconds: 400_000_000)

        let joined = viewModel.plan.tasks.map(\.text).joined(separator: " ").lowercased()
        XCTAssertTrue(joined.contains("nine"), "Expected newer transcript to win; got: \(joined)")
        XCTAssertFalse(joined.contains("first"), "Stale flush should not keep first-transcript tasks; got: \(joined)")
    }

    func testLiveNoTaskExtractionSetsStatusWithoutSwitchingToText() async throws {
        let extractor = ThrowingEmptyModelExtractor()
        let viewModel = AppViewModel(
            defaults: defaults,
            voiceDraftExtractor: extractor,
            liveExtractionDebounceNanoseconds: 60_000_000
        )
        viewModel.selectedInputMode = .voice

        viewModel.updateVoiceTranscriptSnapshot("some, words, here, now, please, thanks, extra, padding")
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertNil(viewModel.voiceDraft)
        XCTAssertTrue(viewModel.extractionStatus.contains("No tasks extracted"))
        XCTAssertEqual(viewModel.selectedInputMode, .voice)
    }

    func testOverflowFromLiveHeuristicExtraction() async throws {
        let viewModel = AppViewModel(
            defaults: defaults,
            voiceDraftExtractor: HeuristicVoiceDraftExtractor(),
            liveExtractionDebounceNanoseconds: 60_000_000
        )
        viewModel.selectedInputMode = .voice

        viewModel.updateVoiceTranscriptSnapshot("a, b, c, d, e, f, g, h")
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertTrue(viewModel.plan.detectedMoreThanThree)
        XCTAssertFalse(viewModel.plan.extras.isEmpty)
    }

    func testCorrectionReplacesDraftFromLatestTranscript() async throws {
        let extractor = ScriptedVoiceExtractor()
        let viewModel = AppViewModel(
            defaults: defaults,
            voiceDraftExtractor: extractor,
            liveExtractionDebounceNanoseconds: 60_000_000
        )
        viewModel.selectedInputMode = .voice

        viewModel.updateVoiceTranscriptSnapshot(
            "PHASE1 alpha, beta, gamma, delta, epsilon, zeta, eta, theta"
        )
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(viewModel.plan.tasks[0].text, "A")

        viewModel.updateVoiceTranscriptSnapshot(
            "PHASE2 one, two, three, four, five, six, seven, eight"
        )
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(viewModel.plan.tasks[0].text, "OnlyNew")
    }
}

// MARK: - Test doubles

private final class SlowHeuristicExtractor: VoiceDraftExtracting, @unchecked Sendable {
    let providerName = "SlowHeuristic"
    private let delayNanoseconds: UInt64
    private let inner = HeuristicVoiceDraftExtractor()

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func extractDraft(from transcript: String) async throws -> VoiceExtractionDraft {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try await inner.extractDraft(from: transcript)
    }
}

private final class ThrowingEmptyModelExtractor: VoiceDraftExtracting, @unchecked Sendable {
    let providerName = "ThrowingEmpty"

    func extractDraft(from transcript: String) async throws -> VoiceExtractionDraft {
        _ = transcript
        throw VoiceDraftExtractionError.emptyModelOutput
    }
}

private final class ScriptedVoiceExtractor: VoiceDraftExtracting, @unchecked Sendable {
    let providerName = "Scripted"

    func extractDraft(from transcript: String) async throws -> VoiceExtractionDraft {
        if transcript.contains("PHASE1") {
            return try VoiceDraftPostProcessor.buildDraft(
                selectedTasks: ["A", "B", "C"],
                extraCandidates: [],
                detectedMoreThanThree: false,
                cleanedTranscript: transcript
            )
        }
        if transcript.contains("PHASE2") {
            return try VoiceDraftPostProcessor.buildDraft(
                selectedTasks: ["OnlyNew"],
                extraCandidates: [],
                detectedMoreThanThree: false,
                cleanedTranscript: transcript
            )
        }
        throw VoiceDraftExtractionError.emptyModelOutput
    }
}

private final class CountingHeuristicExtractor: VoiceDraftExtracting, @unchecked Sendable {
    let providerName = "CountingHeuristic"
    var callCount = 0
    private(set) var lastTranscript: String?
    private let inner = HeuristicVoiceDraftExtractor()

    func extractDraft(from transcript: String) async throws -> VoiceExtractionDraft {
        callCount += 1
        lastTranscript = transcript
        return try await inner.extractDraft(from: transcript)
    }
}

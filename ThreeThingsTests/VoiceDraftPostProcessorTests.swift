import XCTest
@testable import ThreeThings

final class VoiceDraftPostProcessorTests: XCTestCase {
    func testExtrasForceOverflowFlag() throws {
        let draft = try VoiceDraftPostProcessor.buildDraft(
            selectedTasks: ["A", "B", "C"],
            extraCandidates: ["D"],
            detectedMoreThanThree: false,
            cleanedTranscript: "A B C D"
        )
        XCTAssertTrue(draft.detectedMoreThanThree)
        XCTAssertEqual(draft.extraCandidates, ["D"])
    }

    func testLongCandidatesClampToOneHundred() throws {
        let longSelected = String(repeating: "a", count: 140)
        let longExtra = String(repeating: "b", count: 140)
        let draft = try VoiceDraftPostProcessor.buildDraft(
            selectedTasks: [longSelected],
            extraCandidates: [longExtra],
            detectedMoreThanThree: true,
            cleanedTranscript: longSelected
        )
        XCTAssertEqual(draft.selectedTasks[0].count, 100)
        XCTAssertEqual(draft.extraCandidates[0].count, 100)
    }

    func testDuplicateSelectedTasksAreDeduplicated() throws {
        let draft = try VoiceDraftPostProcessor.buildDraft(
            selectedTasks: ["Ship app", "ship app", "Write docs"],
            extraCandidates: [],
            detectedMoreThanThree: false,
            cleanedTranscript: "Ship app write docs"
        )
        XCTAssertEqual(draft.selectedTasks, ["Ship app", "Write docs"])
    }

    func testEmptySelectedThrows() {
        XCTAssertThrowsError(
            try VoiceDraftPostProcessor.buildDraft(
                selectedTasks: ["", "  "],
                extraCandidates: [],
                detectedMoreThanThree: false,
                cleanedTranscript: "x"
            )
        ) { error in
            XCTAssertEqual(error as? VoiceDraftExtractionError, .emptyModelOutput)
        }
    }

    func testNoActionableTasksThrowsEvenWhenModelInventsTasks() {
        XCTAssertThrowsError(
            try VoiceDraftPostProcessor.buildDraft(
                selectedTasks: ["Prepare for meeting", "Review emails", "Call client"],
                extraCandidates: ["Organize workspace", "Set reminders"],
                detectedMoreThanThree: true,
                containsActionableTasks: false,
                cleanedTranscript: "Hello? Testing, testing."
            )
        ) { error in
            XCTAssertEqual(error as? VoiceDraftExtractionError, .emptyModelOutput)
        }
    }
}

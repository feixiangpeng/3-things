import Foundation
import XCTest

@testable import ThreeThings

final class VoiceExtractionEvalScorerTests: XCTestCase {
    func testPassesLiteralThreeTasks() {
        let evalCase = VoiceExtractionEvalCase(
            id: "t",
            category: "literal",
            transcriptVariants: [],
            expectedSelectedMeanings: ["go to a store", "go to the park", "eat food"],
            expectedExtraMeanings: [],
            expectedOverflow: false,
            expectsNoDraft: false,
            forbiddenMeanings: ["buy groceries"],
            notes: nil
        )
        let draft = VoiceExtractionDraft(
            selectedTasks: ["Go to a store", "Go to the park", "Eat food"],
            extraCandidates: [],
            detectedMoreThanThree: false,
            cleanedTranscript: ""
        )
        let score = VoiceExtractionEvalScorer.score(evalCase: evalCase, draft: draft, extractionError: nil)
        XCTAssertTrue(score.passed, "Expected pass; got \(score.reasons)")
    }

    func testFailsWhenForbiddenAppearsInSelected() {
        let evalCase = VoiceExtractionEvalCase(
            id: "t",
            category: "inference_trap",
            transcriptVariants: [],
            expectedSelectedMeanings: ["go to the store"],
            expectedExtraMeanings: [],
            expectedOverflow: false,
            expectsNoDraft: false,
            forbiddenMeanings: ["buy groceries"],
            notes: nil
        )
        let draft = VoiceExtractionDraft(
            selectedTasks: ["Go to the store and buy groceries"],
            extraCandidates: [],
            detectedMoreThanThree: false,
            cleanedTranscript: ""
        )
        let score = VoiceExtractionEvalScorer.score(evalCase: evalCase, draft: draft, extractionError: nil)
        XCTAssertFalse(score.passed)
        XCTAssertTrue(score.reasons.contains(VoiceExtractionEvalFailureReason.inventedSelected))
    }

    func testFailsWrongOverflowFlag() {
        let evalCase = VoiceExtractionEvalCase(
            id: "t",
            category: "overflow",
            transcriptVariants: [],
            expectedSelectedMeanings: ["a", "b", "c"],
            expectedExtraMeanings: ["d"],
            expectedOverflow: true,
            expectsNoDraft: false,
            forbiddenMeanings: [],
            notes: nil
        )
        let draft = VoiceExtractionDraft(
            selectedTasks: ["a", "b", "c"],
            extraCandidates: ["d"],
            detectedMoreThanThree: false,
            cleanedTranscript: ""
        )
        let score = VoiceExtractionEvalScorer.score(evalCase: evalCase, draft: draft, extractionError: nil)
        XCTAssertFalse(score.passed)
        XCTAssertTrue(score.reasons.contains(VoiceExtractionEvalFailureReason.wrongOverflow))
    }

    func testPassesNoDraftWhenModelReturnsEmptyOutputError() {
        let evalCase = VoiceExtractionEvalCase(
            id: "t",
            category: "no_task",
            transcriptVariants: [],
            expectedSelectedMeanings: [],
            expectedExtraMeanings: [],
            expectedOverflow: false,
            expectsNoDraft: true,
            forbiddenMeanings: ["prepare for meeting"],
            notes: nil
        )
        let score = VoiceExtractionEvalScorer.score(
            evalCase: evalCase,
            draft: nil,
            extractionError: VoiceDraftExtractionError.emptyModelOutput
        )
        XCTAssertTrue(score.passed)
    }

    func testFailsNoDraftWhenTasksReturned() {
        let evalCase = VoiceExtractionEvalCase(
            id: "t",
            category: "no_task",
            transcriptVariants: [],
            expectedSelectedMeanings: [],
            expectedExtraMeanings: [],
            expectedOverflow: false,
            expectsNoDraft: true,
            forbiddenMeanings: [],
            notes: nil
        )
        let draft = VoiceExtractionDraft(
            selectedTasks: ["Call client"],
            extraCandidates: [],
            detectedMoreThanThree: false,
            cleanedTranscript: ""
        )
        let score = VoiceExtractionEvalScorer.score(evalCase: evalCase, draft: draft, extractionError: nil)
        XCTAssertFalse(score.passed)
        XCTAssertTrue(score.reasons.contains(VoiceExtractionEvalFailureReason.noTaskFalsePositive))
    }

    func testFailsDuplicateNotCollapsed() {
        let evalCase = VoiceExtractionEvalCase(
            id: "t",
            category: "duplicate",
            transcriptVariants: [],
            expectedSelectedMeanings: ["email Sam", "pay rent"],
            expectedExtraMeanings: [],
            expectedOverflow: false,
            expectsNoDraft: false,
            forbiddenMeanings: [],
            notes: nil
        )
        let draft = VoiceExtractionDraft(
            selectedTasks: ["Email Sam", "Email Sam", "Pay rent"],
            extraCandidates: [],
            detectedMoreThanThree: false,
            cleanedTranscript: ""
        )
        let score = VoiceExtractionEvalScorer.score(evalCase: evalCase, draft: draft, extractionError: nil)
        XCTAssertFalse(score.passed)
        XCTAssertTrue(score.reasons.contains(VoiceExtractionEvalFailureReason.duplicateNotCollapsed))
    }

    func testNormalizeAndSemanticOverlap() {
        let a = VoiceExtractionEvalScorer.normalizeForComparison("  Go   to THE Store!! ")
        XCTAssertEqual(a, "go to store")
        XCTAssertTrue(
            VoiceExtractionEvalScorer.meaningMatches(expectedMeaning: "go to a store", outputPhrase: "go to the store")
        )
        XCTAssertTrue(
            VoiceExtractionEvalScorer.meaningMatches(expectedMeaning: "finish the deck", outputPhrase: "Finish deck slides")
        )
    }
}

import Foundation
import XCTest

@testable import ThreeThings

final class VoiceExtractionEvalFixtureTests: XCTestCase {
    func testFixturesLoadAndValidate() throws {
        let bundle = Bundle(for: VoiceExtractionEvalFixtureTests.self)
        let cases = try VoiceExtractionEvalLoader.loadCases(from: bundle)
        XCTAssertFalse(cases.isEmpty, "Expected eval cases from bundled JSON.")

        var seenIDs = Set<String>()
        for evalCase in cases {
            XCTAssertFalse(evalCase.id.isEmpty, "Case ID must not be empty.")
            XCTAssertTrue(
                seenIDs.insert(evalCase.id).inserted,
                "Duplicate eval case id: \(evalCase.id)"
            )
            XCTAssertFalse(evalCase.category.isEmpty, "Category must not be empty for \(evalCase.id).")
            XCTAssertFalse(evalCase.transcriptVariants.isEmpty, "At least one transcript variant for \(evalCase.id).")

            for (i, t) in evalCase.transcriptVariants.enumerated() {
                XCTAssertFalse(
                    t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty,
                    "Transcript \(i) empty for \(evalCase.id)"
                )
            }

            for f in evalCase.forbiddenMeanings {
                XCTAssertFalse(
                    f.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty,
                    "Forbidden meanings must be non-empty strings for \(evalCase.id)"
                )
                let n = VoiceExtractionEvalScorer.normalizeForComparison(f)
                XCTAssertFalse(n.isEmpty, "Forbidden normalizes to empty in \(evalCase.id)")
            }

            if evalCase.expectsNoDraft {
                XCTAssertTrue(
                    evalCase.expectedSelectedMeanings.isEmpty,
                    "expectsNoDraft implies no expected selected meanings (\(evalCase.id))"
                )
                XCTAssertTrue(
                    evalCase.expectedExtraMeanings.isEmpty,
                    "expectsNoDraft implies no expected extras (\(evalCase.id))"
                )
                XCTAssertFalse(evalCase.expectedOverflow, "Mic/filler cases should not expect overflow (\(evalCase.id))")
            } else {
                if evalCase.expectedOverflow {
                    XCTAssertEqual(
                        evalCase.expectedSelectedMeanings.count,
                        3,
                        "Overflow cases should state three top tasks in fixtures (\(evalCase.id))"
                    )
                    XCTAssertGreaterThanOrEqual(
                        evalCase.expectedExtraMeanings.count,
                        1,
                        "Overflow true should have at least one extra meaning (\(evalCase.id))"
                    )
                    XCTAssertGreaterThan(
                        evalCase.expectedSelectedMeanings.count + evalCase.expectedExtraMeanings.count,
                        3,
                        "Overflow true implies >3 explicit tasks in fixture (\(evalCase.id))"
                    )
                } else {
                    XCTAssertTrue(
                        evalCase.expectedExtraMeanings.isEmpty,
                        "Non-overflow cases should have no expected extras (\(evalCase.id))"
                    )
                }
            }
        }
    }

    func testRequiredCaseIdsPresent() throws {
        let bundle = Bundle(for: VoiceExtractionEvalFixtureTests.self)
        let cases = try VoiceExtractionEvalLoader.loadCases(from: bundle)
        let ids = Set(cases.map { $0.id })
        let required: Set<String> = [
            "literal_three_store_park_food",
            "overflow_four_clean",
            "correction_never_mind_single",
            "no_task_testing",
            "inference_store_only",
            "duplicate_email_sam",
            "ramble_two_clear_tasks"
        ]
        XCTAssertTrue(required.isSubset(of: ids))
    }
}

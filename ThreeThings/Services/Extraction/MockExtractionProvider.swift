import Foundation

struct MockExtractionProvider: ExtractionProvider {
    let name = "Mock"

    func extract(from transcript: String) async throws -> ExtractionResult {
        let split = transcript
            .split(whereSeparator: { ",.\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let deduped = Array(NSOrderedSet(array: split)) as? [String] ?? split
        let tasks = Array(deduped.prefix(3))
        let extras = deduped.count > 3 ? Array(deduped.dropFirst(3)) : []

        return ExtractionResult(
            tasks: tasks,
            extras: extras,
            detectedMoreThanThree: deduped.count > 3
        )
    }
}

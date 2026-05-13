import Foundation

enum VoiceDraftExtractionError: LocalizedError, Equatable {
    case emptyTranscript
    case modelUnavailable
    case localeUnsupported
    case emptyModelOutput

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            return "No transcript text to extract from."
        case .modelUnavailable:
            return "On-device AI is unavailable or not ready. Type instead."
        case .localeUnsupported:
            return "This language is not supported by on-device AI yet. Type instead."
        case .emptyModelOutput:
            return "No tasks extracted from transcript."
        }
    }
}

protocol VoiceDraftExtracting: Sendable {
    var providerName: String { get }
    func extractDraft(from transcript: String) async throws -> VoiceExtractionDraft
}

/// Deterministic split-based extractor used in unit tests and on the Simulator (no live model).
struct HeuristicVoiceDraftExtractor: VoiceDraftExtracting {
    let providerName = "Heuristic"

    func extractDraft(from transcript: String) async throws -> VoiceExtractionDraft {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VoiceDraftExtractionError.emptyTranscript }

        let split = trimmed
            .split(whereSeparator: { ",.\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let deduped = Array(NSOrderedSet(array: split)) as? [String] ?? split
        let tasks = Array(deduped.prefix(3))
        let extras = deduped.count > 3 ? Array(deduped.dropFirst(3)) : []

        return try VoiceDraftPostProcessor.buildDraft(
            selectedTasks: tasks,
            extraCandidates: extras,
            detectedMoreThanThree: deduped.count > 3,
            cleanedTranscript: trimmed
        )
    }
}

enum VoiceDraftPostProcessor {
    /// Normalizes model / heuristic output into a `VoiceExtractionDraft` with caps, deduping, and overflow rules.
    static func buildDraft(
        selectedTasks: [String],
        extraCandidates: [String],
        detectedMoreThanThree: Bool,
        containsActionableTasks: Bool = true,
        cleanedTranscript: String
    ) throws -> VoiceExtractionDraft {
        let cleaned = cleanedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard containsActionableTasks else {
            throw VoiceDraftExtractionError.emptyModelOutput
        }

        var selected: [String] = []
        var seen = Set<String>()

        for raw in selectedTasks {
            let text = String(raw.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = text.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            selected.append(text)
            if selected.count == 3 { break }
        }

        var extras = extraCandidates
            .map { String($0.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        extras = extras.filter { candidate in
            let key = candidate.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }

        var overflow = detectedMoreThanThree || !extras.isEmpty

        // If we still have more raw selected items than we kept, treat as overflow.
        if selectedTasks.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).count > 3 {
            overflow = true
        }

        guard !selected.isEmpty else {
            throw VoiceDraftExtractionError.emptyModelOutput
        }

        return VoiceExtractionDraft(
            selectedTasks: selected,
            extraCandidates: extras,
            detectedMoreThanThree: overflow,
            cleanedTranscript: cleaned
        )
    }
}

enum AppVoiceDraftExtractorFactory {
    /// Simulator builds use deterministic extraction; devices use Apple Foundation Models when available.
    static func `default`() -> any VoiceDraftExtracting {
        #if targetEnvironment(simulator)
        return HeuristicVoiceDraftExtractor()
        #else
        return FoundationModelsVoiceDraftExtractor()
        #endif
    }
}

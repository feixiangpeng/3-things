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
    /// Normalizes model / heuristic output into a `VoiceExtractionDraft`. Applies deterministic
    /// repair steps that complement the prompt:
    ///   1. Trim, length-cap, and exact-lowercase dedup within selected and extras.
    ///   2. Semantic dedup: drop extras that share substantial tokens with an already-selected task
    ///      ("send Sam an email" duplicates "email Sam") via Jaccard ≥ 0.55.
    ///   3. Promote extras into selected when selected has room (model often under-fills selected).
    ///   4. Cap selected at 3, pushing excess to extras.
    ///   5. Recompute overflow as (extras non-empty OR original raw selected > 3).
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

        // 1. Clean + exact-dedup selected.
        var selected: [String] = []
        var seenLowercase = Set<String>()
        for raw in selectedTasks {
            let text = String(raw.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = text.lowercased()
            guard !seenLowercase.contains(key) else { continue }
            // Drop if semantically duplicates an already-kept selected item.
            if selected.contains(where: { isSemanticDuplicate($0, text) }) { continue }
            seenLowercase.insert(key)
            selected.append(text)
        }

        // 2. Clean + dedup extras against selected and each other.
        var extras: [String] = []
        for raw in extraCandidates {
            let text = String(raw.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = text.lowercased()
            if seenLowercase.contains(key) { continue }
            if selected.contains(where: { isSemanticDuplicate($0, text) }) { continue }
            if extras.contains(where: { isSemanticDuplicate($0, text) }) { continue }
            seenLowercase.insert(key)
            extras.append(text)
        }

        // 3. Promote extras → selected if selected has room.
        while selected.count < 3, !extras.isEmpty {
            let candidate = extras.removeFirst()
            if selected.contains(where: { isSemanticDuplicate($0, candidate) }) { continue }
            selected.append(candidate)
        }

        // 4. Cap selected at 3; overflow into extras (preserve order).
        if selected.count > 3 {
            let overflowItems = Array(selected[3...])
            selected = Array(selected[..<3])
            extras = overflowItems + extras
        }

        // 5. Recompute overflow.
        var overflow = !extras.isEmpty
        if selectedTasks.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).count > 3 {
            overflow = true
        }
        if detectedMoreThanThree, !extras.isEmpty {
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

    /// True when two task strings share enough meaningful tokens (Jaccard ≥ 0.55) that they
    /// represent the same action — e.g. "email Sam" vs "send Sam an email".
    static func isSemanticDuplicate(_ a: String, _ b: String) -> Bool {
        let ta = meaningTokens(a)
        let tb = meaningTokens(b)
        guard ta.count >= 2, tb.count >= 2 else {
            // Single-meaningful-token tasks fall back to exact normalized match.
            return normalizedTokens(a) == normalizedTokens(b)
        }
        let inter = ta.intersection(tb)
        guard inter.count >= 2 else { return false }
        let union = ta.union(tb)
        return Double(inter.count) / Double(union.count) >= 0.55
    }

    /// Lowercase token set, stop-words and short particles removed.
    private static func meaningTokens(_ text: String) -> Set<String> {
        let folded = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        let lowered = folded.lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scrubbed = String(String.UnicodeScalarView(lowered.unicodeScalars.map { allowed.contains($0) ? $0 : " " }))
        let stop: Set<String> = ["a", "an", "the", "to", "for", "of", "and", "or", "with", "on", "in", "at", "by", "is", "am", "are", "be"]
        return Set(scrubbed.split(separator: " ").map(String.init).filter { $0.count > 1 && !stop.contains($0) })
    }

    private static func normalizedTokens(_ text: String) -> String {
        let folded = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        let lowered = folded.lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scrubbed = String(String.UnicodeScalarView(lowered.unicodeScalars.map { allowed.contains($0) ? $0 : " " }))
        return scrubbed.split(separator: " ").map(String.init).filter { !$0.isEmpty }.joined(separator: " ")
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

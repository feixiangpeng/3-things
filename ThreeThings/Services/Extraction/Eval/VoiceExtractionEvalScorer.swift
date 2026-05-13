import Foundation

enum VoiceExtractionEvalFailureReason: String, Equatable, CaseIterable {
    case inventedSelected = "invented_selected"
    case inventedExtra = "invented_extra"
    case missingTask = "missing_task"
    case wrongOverflow = "wrong_overflow"
    case ignoredCorrection = "ignored_correction"
    case duplicateNotCollapsed = "duplicate_not_collapsed"
    case overSpecificRewrite = "over_specific_rewrite"
    case noTaskFalsePositive = "no_task_false_positive"
    case badGrouping = "bad_grouping"
}

struct VoiceExtractionEvalAttemptScore: Equatable {
    var passed: Bool
    var reasons: [VoiceExtractionEvalFailureReason]

    static let pass = VoiceExtractionEvalAttemptScore(passed: true, reasons: [])
}

enum VoiceExtractionEvalScorer {
    /// Scores a single extraction attempt against a fixture. Supply at most one of `draft` or a meaningful `extractionError`.
    static func score(
        evalCase: VoiceExtractionEvalCase,
        draft: VoiceExtractionDraft?,
        extractionError: Error?
    ) -> VoiceExtractionEvalAttemptScore {
        if evalCase.expectsNoDraft {
            return scoreNoDraftCase(evalCase: evalCase, draft: draft, extractionError: extractionError)
        }
        return scoreDraftExpected(evalCase: evalCase, draft: draft, extractionError: extractionError)
    }

    // MARK: - Normalization

    static func normalizeForComparison(_ text: String) -> String {
        let folded = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        let lowered = folded.lowercased()
        let scalars = lowered.unicodeScalars.map { uc -> String in
            if CharacterSet.alphanumerics.contains(uc) || uc == " " {
                return String(String.UnicodeScalarView([uc]))
            }
            return " "
        }.joined()
        let parts = scalars.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let stop: Set<String> = ["a", "an", "the"]
        return parts.filter { !stop.contains($0) && !$0.isEmpty }.joined(separator: " ")
    }

    static func meaningMatches(expectedMeaning: String, outputPhrase: String) -> Bool {
        let e = normalizeForComparison(expectedMeaning)
        let o = normalizeForComparison(outputPhrase)
        guard !e.isEmpty, !o.isEmpty else { return false }
        if o.contains(e) || e.contains(o) {
            return true
        }
        return tokenCoverageMatches(expectedTokens: e, candidateTokens: o, minimumCoverage: 0.5)
    }

    private static func tokenCoverageMatches(expectedTokens: String, candidateTokens: String, minimumCoverage: Double) -> Bool {
        let exp = Set(expectedTokens.split(separator: " ").map(String.init).filter { $0.count > 1 })
        let cand = Set(candidateTokens.split(separator: " ").map(String.init).filter { $0.count > 1 })
        guard !exp.isEmpty else { return false }
        let inter = exp.intersection(cand)
        return Double(inter.count) / Double(exp.count) >= minimumCoverage
    }

    // MARK: - Private modes

    private static func scoreNoDraftCase(
        evalCase: VoiceExtractionEvalCase,
        draft: VoiceExtractionDraft?,
        extractionError: Error?
    ) -> VoiceExtractionEvalAttemptScore {
        var reasons: [VoiceExtractionEvalFailureReason] = []

        if let draft, !draft.selectedTasks.isEmpty || !draft.extraCandidates.isEmpty {
            reasons.append(.noTaskFalsePositive)
            reasons.append(contentsOf: checkForbidden(
                evalCase: evalCase,
                selected: draft.selectedTasks,
                extras: draft.extraCandidates
            ))
            return dedupedScore(reasons)
        }

        if let err = extractionError as? VoiceDraftExtractionError, err == .emptyModelOutput || err == .emptyTranscript {
            return .pass
        }

        if extractionError == nil {
            return .pass
        }

        reasons.append(.noTaskFalsePositive)
        return dedupedScore(reasons)
    }

    private static func scoreDraftExpected(
        evalCase: VoiceExtractionEvalCase,
        draft: VoiceExtractionDraft?,
        extractionError: Error?
    ) -> VoiceExtractionEvalAttemptScore {
        var reasons: [VoiceExtractionEvalFailureReason] = []

        guard let draft else {
            reasons.append(.missingTask)
            return dedupedScore(reasons)
        }

        if draft.detectedMoreThanThree != evalCase.expectedOverflow {
            reasons.append(.wrongOverflow)
        }

        reasons.append(contentsOf: checkForbidden(
            evalCase: evalCase,
            selected: draft.selectedTasks,
            extras: draft.extraCandidates
        ))

        var usedSelected = Set<Int>()
        for expected in evalCase.expectedSelectedMeanings {
            if let idx = draft.selectedTasks.enumerated().first(where: { !usedSelected.contains($0.offset) && meaningMatches(expectedMeaning: expected, outputPhrase: $0.element) })?.offset {
                usedSelected.insert(idx)
            } else {
                reasons.append(.missingTask)
            }
        }

        for (offset, sel) in draft.selectedTasks.enumerated() where !usedSelected.contains(offset) {
            let matchesExpected = evalCase.expectedSelectedMeanings.contains { meaningMatches(expectedMeaning: $0, outputPhrase: sel) }
            if !matchesExpected {
                if evalCase.category.hasPrefix("correction") {
                    reasons.append(.ignoredCorrection)
                } else {
                    reasons.append(.inventedSelected)
                }
            }
        }

        if evalCase.expectedExtraMeanings.isEmpty, !draft.extraCandidates.isEmpty {
            reasons.append(.inventedExtra)
        }

        var usedExtras = Set<Int>()
        for expected in evalCase.expectedExtraMeanings {
            if let idx = draft.extraCandidates.enumerated().first(where: { !usedExtras.contains($0.offset) && meaningMatches(expectedMeaning: expected, outputPhrase: $0.element) })?.offset {
                usedExtras.insert(idx)
            } else {
                reasons.append(.missingTask)
            }
        }

        for (offset, ex) in draft.extraCandidates.enumerated() where !usedExtras.contains(offset) {
            let ok = evalCase.expectedExtraMeanings.contains { meaningMatches(expectedMeaning: $0, outputPhrase: ex) }
            if !ok {
                reasons.append(.inventedExtra)
            }
        }

        if hasSemanticDuplicateTasks(draft.selectedTasks) {
            reasons.append(.duplicateNotCollapsed)
        }

        if evalCase.category == "inference_trap" {
            for sel in draft.selectedTasks {
                for expected in evalCase.expectedSelectedMeanings where meaningMatches(expectedMeaning: expected, outputPhrase: sel) {
                    let exNorm = normalizeForComparison(expected)
                    let selNorm = normalizeForComparison(sel)
                    if selNorm.count > exNorm.count + 12 {
                        reasons.append(.overSpecificRewrite)
                    }
                }
            }
        }

        return dedupedScore(reasons)
    }

    private static func dedupedScore(_ reasons: [VoiceExtractionEvalFailureReason]) -> VoiceExtractionEvalAttemptScore {
        let unique = Array(Set(reasons)).sorted { $0.rawValue < $1.rawValue }
        return VoiceExtractionEvalAttemptScore(passed: unique.isEmpty, reasons: unique)
    }

    private static func checkForbidden(
        evalCase: VoiceExtractionEvalCase,
        selected: [String],
        extras: [String]
    ) -> [VoiceExtractionEvalFailureReason] {
        var out: [VoiceExtractionEvalFailureReason] = []
        let fields = selected + extras
        for forbidden in evalCase.forbiddenMeanings {
            let f = normalizeForComparison(forbidden)
            guard !f.isEmpty else { continue }
            for (idx, field) in fields.enumerated() {
                let n = normalizeForComparison(field)
                guard !n.isEmpty else { continue }
                if n.contains(f) || f.contains(n) {
                    let inSelected = idx < selected.count
                    out.append(inSelected ? .inventedSelected : .inventedExtra)
                }
            }
        }
        return out
    }

    private static func hasSemanticDuplicateTasks(_ tasks: [String]) -> Bool {
        for i in tasks.indices {
            for j in tasks.indices where j > i {
                if isDuplicateTaskPair(tasks[i], tasks[j]) {
                    return true
                }
            }
        }
        return false
    }

    /// Stricter than meaning matching: requires substantial token overlap (not just a shared "go").
    private static func isDuplicateTaskPair(_ a: String, _ b: String) -> Bool {
        let ta = Set(normalizeForComparison(a).split(separator: " ").map(String.init).filter { $0.count > 1 })
        let tb = Set(normalizeForComparison(b).split(separator: " ").map(String.init).filter { $0.count > 1 })
        guard ta.count >= 2, tb.count >= 2 else {
            return meaningMatches(expectedMeaning: a, outputPhrase: b) && normalizeForComparison(a) == normalizeForComparison(b)
        }
        let inter = ta.intersection(tb)
        let union = ta.union(tb)
        guard inter.count >= 2 else { return false }
        let jaccard = Double(inter.count) / Double(union.count)
        return jaccard >= 0.55
    }
}

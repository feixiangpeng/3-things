import Foundation
import FoundationModels

@Generable(description: "Extracts a small set of actionable daily tasks from English speech text.")
struct GeneratedVoiceDraft {
    @Guide(description: "Up to three short actionable tasks for today, highest priority first.", .count(0...3))
    var selectedTasks: [String]

    @Guide(description: "Additional actionable tasks not in the top three.", .count(0...20))
    var extraCandidates: [String]

    @Guide(description: "True when more than three distinct actionable tasks appear in the transcript.")
    var detectedMoreThanThree: Bool
}

struct FoundationModelsVoiceDraftExtractor: VoiceDraftExtracting {
    let providerName = "Apple Foundation Models"

    func extractDraft(from transcript: String) async throws -> VoiceExtractionDraft {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VoiceDraftExtractionError.emptyTranscript }

        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            throw VoiceDraftExtractionError.modelUnavailable
        }

        guard model.supportsLocale(.current) else {
            throw VoiceDraftExtractionError.localeUnsupported
        }

        let session = LanguageModelSession(model: model)

        let prompt = """
        You help the user pick 1-3 focus tasks for TODAY from a voice transcript (English).

        Rules:
        - Each task is concise (under 100 characters), starts with an imperative verb when possible.
        - Preserve the user's spoken order when choosing the top tasks.
        - De-duplicate near-duplicates.
        - Put additional distinct actionable items in extraCandidates.
        - Set detectedMoreThanThree true if there are more than three distinct actionable tasks.

        Transcript:
        \(trimmed)
        """

        let response = try await session.respond(to: prompt, generating: GeneratedVoiceDraft.self)
        return try VoiceDraftPostProcessor.buildDraft(
            selectedTasks: response.content.selectedTasks,
            extraCandidates: response.content.extraCandidates,
            detectedMoreThanThree: response.content.detectedMoreThanThree,
            cleanedTranscript: trimmed
        )
    }
}

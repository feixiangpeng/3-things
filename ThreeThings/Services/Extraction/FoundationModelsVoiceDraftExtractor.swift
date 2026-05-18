import Foundation
import FoundationModels

@Generable(description: "Extracts a small set of actionable daily tasks from English speech text.")
struct GeneratedVoiceDraft {
    @Guide(description: "True only if the transcript contains explicit actionable tasks or commitments.")
    var containsActionableTasks: Bool

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
        Extract today's focus tasks from a voice transcript. Output ONE JSON object only.

        WHAT GOES IN EACH FIELD:
        - selectedTasks: the FIRST 1, 2, or 3 tasks the user mentioned for TODAY, IN THE ORDER THEY SAID THEM. Max 3. Do NOT reorder by priority, importance, or type.
        - extraCandidates: tasks 4, 5, ... ONLY if more than 3 distinct surviving tasks. Otherwise [].
        - detectedMoreThanThree: true iff >3 surviving distinct tasks.
        - containsActionableTasks: false ONLY for filler/mic-test/greeting. Do NOT set false just because tasks are phrased informally.

        CRITICAL: extraCandidates is NEVER for cancelled tasks, duplicate wordings, or things you are unsure about. Those simply DO NOT appear anywhere in the output.

        PROCESS (do not show your work):
        1. List every task the user actually said, in spoken order. Number them 1, 2, 3, 4...
        2. DELETE cancelled tasks: any task immediately before phrases like "never mind", "wait never mind", "scratch that", "actually no", "wait no", "cancel that", "skip X", "not X Y instead" — gone, not in any field.
        3. DELETE duplicate wordings: "email Sam" and "send Sam an email" mean the same action — keep the cleanest wording ONCE.
        4. DELETE future-day tasks: any task framed with "tomorrow", "next week", "next month", "later", "not today", or "another day" is gone. This applies even if spoken first. KEEP tasks framed with "today" or with no time frame.
        5. Count what remains. If ≤3, selectedTasks=all, extraCandidates=[]. If >3, selectedTasks=tasks 1, 2, 3 IN ORDER, extraCandidates=tasks 4, 5, etc.

        VAGUE BUT STATED ARE VALID TASKS:
        - "Deal with taxes", "handle tax stuff" — keep AS STATED. These ARE tasks. ALWAYS set containsActionableTasks=true when there is an explicit task or commitment, even if vaguely phrased.

        ALSO:
        - No inference. "Call the doctor" ≠ "schedule appointment". Keep vague tasks vague.
        - "Don't X" / "stay off X" / "avoid X" — VALID task, keep the phrasing.
        - Substeps under a named parent collapse to the parent ("launch email: subject, body, send" → "finish launch email").

        EXAMPLES:

        Transcript: Write the report, actually no, write the brief.
        Output: selectedTasks=["write the brief"], extraCandidates=[], detectedMoreThanThree=false

        Transcript: Call Bob, wait never mind, call Alice.
        Output: selectedTasks=["call Alice"], extraCandidates=[], detectedMoreThanThree=false

        Transcript: Pay rent, send Jamie the email, email Jamie about the thing.
        Output: selectedTasks=["pay rent","email Jamie"], extraCandidates=[], detectedMoreThanThree=false

        Transcript: Email Sam, pay rent, book dentist, call mom.
        Output: selectedTasks=["email Sam","pay rent","book dentist"], extraCandidates=["call mom"], detectedMoreThanThree=true

        Transcript: Task A, task B, task C, task D, task E, task F.
        Output: selectedTasks=["task A","task B","task C"], extraCandidates=["task D","task E","task F"], detectedMoreThanThree=true

        Transcript: Tomorrow call Mark. Today pay the bills.
        Output: selectedTasks=["pay the bills"], extraCandidates=[], detectedMoreThanThree=false

        Transcript: Uh tomorrow call Sam. Today pay rent.
        Output: selectedTasks=["pay rent"], extraCandidates=[], detectedMoreThanThree=false

        Transcript: Handle the tax situation today.
        Output: selectedTasks=["handle the tax situation"], extraCandidates=[], detectedMoreThanThree=false

        Transcript: For the newsletter, write the headline, draft the copy, and send.
        Output: selectedTasks=["finish the newsletter"], extraCandidates=[], detectedMoreThanThree=false

        Transcript: Don't open Instagram today.
        Output: selectedTasks=["don't open Instagram"], extraCandidates=[], detectedMoreThanThree=false

        Transcript: Hello hello, just testing.
        Output: containsActionableTasks=false, selectedTasks=[], extraCandidates=[], detectedMoreThanThree=false

        Now do this one.

        Transcript: \(trimmed)
        """

        let response = try await session.respond(to: prompt, generating: GeneratedVoiceDraft.self)
        return try VoiceDraftPostProcessor.buildDraft(
            selectedTasks: response.content.selectedTasks,
            extraCandidates: response.content.extraCandidates,
            detectedMoreThanThree: response.content.detectedMoreThanThree,
            containsActionableTasks: response.content.containsActionableTasks,
            cleanedTranscript: trimmed
        )
    }
}

import Foundation

struct MockVoiceDraftFixture: Identifiable, Equatable {
    let id: String
    let title: String
    let transcript: String
    let draft: VoiceExtractionDraft
}

struct MockVoiceDraftProvider {
    static let fixtures: [MockVoiceDraftFixture] = [
        MockVoiceDraftFixture(
            id: "one-task",
            title: "Clean 1 task",
            transcript: "Today I need to send the investor update.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Send the investor update"],
                cleanedTranscript: "Send the investor update"
            )
        ),
        MockVoiceDraftFixture(
            id: "three-tasks",
            title: "Clean 3 tasks",
            transcript: "Finish the product spec, call Maya, and book the dentist appointment.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Finish the product spec", "Call Maya", "Book the dentist appointment"],
                cleanedTranscript: "Finish the product spec. Call Maya. Book the dentist appointment."
            )
        ),
        MockVoiceDraftFixture(
            id: "overflow",
            title: "5-task overflow",
            transcript: "I need to write the launch email, fix onboarding, review the PR, pay rent, and clean my desk.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Write the launch email", "Fix onboarding", "Review the PR"],
                extraCandidates: ["Pay rent", "Clean my desk"],
                detectedMoreThanThree: true,
                cleanedTranscript: "Write the launch email. Fix onboarding. Review the PR. Pay rent. Clean my desk."
            )
        ),
        MockVoiceDraftFixture(
            id: "rambling",
            title: "Rambling",
            transcript: "Okay today is messy. I think the real things are prep the demo, email Jordan, and maybe not maybe definitely review the crash logs.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Prep the demo", "Email Jordan", "Review the crash logs"],
                cleanedTranscript: "Prep the demo. Email Jordan. Review the crash logs."
            )
        ),
        MockVoiceDraftFixture(
            id: "never-mind",
            title: "Never mind",
            transcript: "I need to buy groceries, actually never mind, order dinner, finish the outline, and call Sam.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Order dinner", "Finish the outline", "Call Sam"],
                cleanedTranscript: "Order dinner. Finish the outline. Call Sam."
            )
        ),
        MockVoiceDraftFixture(
            id: "replacement",
            title: "Replacement",
            transcript: "Write the blog post, actually replace that with edit the launch post, then update the screenshots.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Edit the launch post", "Update the screenshots"],
                cleanedTranscript: "Edit the launch post. Update the screenshots."
            )
        ),
        MockVoiceDraftFixture(
            id: "duplicates",
            title: "Duplicates",
            transcript: "Review the pull request, check the PR, and send the invoice.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Review the pull request", "Send the invoice"],
                cleanedTranscript: "Review the pull request. Send the invoice."
            )
        ),
        MockVoiceDraftFixture(
            id: "vague",
            title: "Vague",
            transcript: "I should probably deal with the messy finance stuff and make the demo less embarrassing.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Deal with the finance stuff", "Make the demo less embarrassing"],
                cleanedTranscript: "Deal with the finance stuff. Make the demo less embarrassing."
            )
        ),
        MockVoiceDraftFixture(
            id: "long-task",
            title: "Long task",
            transcript: "Create the detailed launch checklist covering support, analytics, onboarding, emails, screenshots, and follow-up notes.",
            draft: VoiceExtractionDraft(
                selectedTasks: ["Create the detailed launch checklist covering support, analytics, onboarding, emails, screenshots"],
                cleanedTranscript: "Create the detailed launch checklist covering support, analytics, onboarding, emails, screenshots, and follow-up notes."
            )
        )
    ]

    func fixture(withID id: String) -> MockVoiceDraftFixture {
        Self.fixtures.first { $0.id == id } ?? Self.fixtures[0]
    }
}

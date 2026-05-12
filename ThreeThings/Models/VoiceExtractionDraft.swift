import Foundation

struct VoiceExtractionDraft: Codable, Equatable {
    var selectedTasks: [String]
    var extraCandidates: [String]
    var detectedMoreThanThree: Bool
    var cleanedTranscript: String

    init(
        selectedTasks: [String],
        extraCandidates: [String] = [],
        detectedMoreThanThree: Bool? = nil,
        cleanedTranscript: String
    ) {
        self.selectedTasks = Array(selectedTasks.prefix(3))
        self.extraCandidates = extraCandidates
        self.detectedMoreThanThree = detectedMoreThanThree ?? (selectedTasks.count + extraCandidates.count > 3)
        self.cleanedTranscript = cleanedTranscript
    }
}

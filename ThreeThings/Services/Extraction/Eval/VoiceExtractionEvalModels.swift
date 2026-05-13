import Foundation

enum VoiceExtractionEvalLoadError: Error, Equatable {
    case missingResource(bundle: String)
}

struct VoiceExtractionEvalFileEnvelope: Codable, Equatable {
    var version: Int
    var cases: [VoiceExtractionEvalCase]
}

struct VoiceExtractionEvalCase: Codable, Equatable, Identifiable {
    var id: String
    var category: String
    /// Multiple wordings per scenario (clean, filler, ASR-ish, etc.).
    var transcriptVariants: [String]
    var expectedSelectedMeanings: [String]
    var expectedExtraMeanings: [String]
    /// Product rule: true iff the transcript states more than three distinct explicit tasks.
    var expectedOverflow: Bool
    /// True for mic tests / filler-only — expect `VoiceDraftExtractionError.emptyModelOutput`, not a draft.
    var expectsNoDraft: Bool
    var forbiddenMeanings: [String]
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case transcriptVariants
        case expectedSelectedMeanings
        case expectedExtraMeanings
        case expectedOverflow
        case expectsNoDraft
        case forbiddenMeanings
        case notes
    }

    init(
        id: String,
        category: String,
        transcriptVariants: [String],
        expectedSelectedMeanings: [String],
        expectedExtraMeanings: [String],
        expectedOverflow: Bool,
        expectsNoDraft: Bool,
        forbiddenMeanings: [String],
        notes: String? = nil
    ) {
        self.id = id
        self.category = category
        self.transcriptVariants = transcriptVariants
        self.expectedSelectedMeanings = expectedSelectedMeanings
        self.expectedExtraMeanings = expectedExtraMeanings
        self.expectedOverflow = expectedOverflow
        self.expectsNoDraft = expectsNoDraft
        self.forbiddenMeanings = forbiddenMeanings
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        category = try c.decode(String.self, forKey: .category)
        transcriptVariants = try c.decode([String].self, forKey: .transcriptVariants)
        expectedSelectedMeanings = try c.decode([String].self, forKey: .expectedSelectedMeanings)
        expectedExtraMeanings = try c.decodeIfPresent([String].self, forKey: .expectedExtraMeanings) ?? []
        expectedOverflow = try c.decode(Bool.self, forKey: .expectedOverflow)
        expectsNoDraft = try c.decodeIfPresent(Bool.self, forKey: .expectsNoDraft) ?? false
        forbiddenMeanings = try c.decodeIfPresent([String].self, forKey: .forbiddenMeanings) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}

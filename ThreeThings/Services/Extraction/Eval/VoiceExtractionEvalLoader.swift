import Foundation

enum VoiceExtractionEvalLoader {
    nonisolated static let resourceName = "voice_extraction_cases"
    nonisolated static let resourceExtension = "json"

    /// Loads eval cases from a bundle that includes `voice_extraction_cases.json` (app or test bundle).
    static func loadCases(from bundle: Bundle = .main) throws -> [VoiceExtractionEvalCase] {
        try loadEnvelope(from: bundle).cases
    }

    static func loadEnvelope(from bundle: Bundle = .main) throws -> VoiceExtractionEvalFileEnvelope {
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw VoiceExtractionEvalLoadError.missingResource(bundle: bundle.bundlePath)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VoiceExtractionEvalFileEnvelope.self, from: data)
    }
}

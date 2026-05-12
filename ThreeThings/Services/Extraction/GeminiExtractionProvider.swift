import Foundation

struct GeminiExtractionProvider: ExtractionProvider {
    let name = "Gemini"

    func extract(from transcript: String) async throws -> ExtractionResult {
        _ = transcript
        throw ExtractionError.notConfigured(name)
    }
}

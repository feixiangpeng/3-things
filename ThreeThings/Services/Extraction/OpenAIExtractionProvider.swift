import Foundation

struct OpenAIExtractionProvider: ExtractionProvider {
    let name = "OpenAI"

    func extract(from transcript: String) async throws -> ExtractionResult {
        _ = transcript
        throw ExtractionError.notConfigured(name)
    }
}

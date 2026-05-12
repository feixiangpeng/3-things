import Foundation

@MainActor
final class ExtractionService {
    private var provider: ExtractionProvider

    init(kind: ExtractionProviderKind = .mock) {
        switch kind {
        case .mock:
            self.provider = MockExtractionProvider()
        case .openAI:
            self.provider = OpenAIExtractionProvider()
        case .gemini:
            self.provider = GeminiExtractionProvider()
        }
    }

    func setProvider(_ kind: ExtractionProviderKind) {
        switch kind {
        case .mock:
            provider = MockExtractionProvider()
        case .openAI:
            provider = OpenAIExtractionProvider()
        case .gemini:
            provider = GeminiExtractionProvider()
        }
    }

    func extract(transcript: String) async throws -> ExtractionResult {
        try await provider.extract(from: transcript)
    }

    var activeProviderName: String {
        provider.name
    }
}

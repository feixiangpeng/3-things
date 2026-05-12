import Foundation

@MainActor
protocol ExtractionProvider {
    var name: String { get }
    func extract(from transcript: String) async throws -> ExtractionResult
}

enum ExtractionProviderKind: String, CaseIterable {
    case mock
    case openAI
    case gemini
}

import Foundation

struct ExtractionResult: Codable, Equatable {
    var tasks: [String]
    var extras: [String]
    var detectedMoreThanThree: Bool
}

enum ExtractionError: Error, LocalizedError {
    case notConfigured(String)
    case networkUnavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured(let provider):
            return "\(provider) extraction provider is not configured."
        case .networkUnavailable:
            return "Network connection required for extraction."
        case .invalidResponse:
            return "Extraction provider returned an invalid response."
        }
    }
}

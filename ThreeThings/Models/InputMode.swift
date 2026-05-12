import Foundation

enum InputMode: String, CaseIterable, Identifiable {
    case text
    case voice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            return "Type"
        case .voice:
            return "Voice"
        }
    }
}

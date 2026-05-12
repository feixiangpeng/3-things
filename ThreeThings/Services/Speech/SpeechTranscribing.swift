import Foundation

enum SpeechPipelineError: LocalizedError, Equatable {
    case unsupportedOS
    case permissionDenied(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "On-device speech recognition requires a newer iOS on a supported device."
        case .permissionDenied(let detail):
            return detail
        case .transcriptionFailed(let detail):
            return detail
        }
    }
}

/// Abstraction over on-device speech-to-text so `SpeechCaptureManager` stays testable.
protocol SpeechTranscribing: Sendable {
    /// Transcribes the given recorded audio file (e.g. M4A from `AVAudioRecorder`).
    func transcribe(audioFileAt url: URL, locale: Locale) async throws -> String
}

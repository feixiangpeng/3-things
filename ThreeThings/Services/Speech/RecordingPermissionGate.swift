import AVFoundation
import Speech

enum RecordingAuthorizationState: Sendable {
    case granted
    case denied(message: String)
}

/// Requests microphone + speech recognition authorization for the voice capture path.
protocol RecordingPermissionGating: Sendable {
    func ensureAuthorizedForRecording() async -> RecordingAuthorizationState
}

/// Production gate using system permission APIs.
struct SystemRecordingPermissionGate: RecordingPermissionGating {
    func ensureAuthorizedForRecording() async -> RecordingAuthorizationState {
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            return .denied(message: "Microphone access is required to record voice tasks.")
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }

        switch speechStatus {
        case .authorized:
            return .granted
        case .denied:
            return .denied(message: "Speech recognition is denied. Enable it in Settings → Privacy → Speech Recognition.")
        case .restricted:
            return .denied(message: "Speech recognition is restricted on this device.")
        case .notDetermined:
            return .denied(message: "Speech recognition permission was not determined.")
        @unknown default:
            return .denied(message: "Speech recognition is not available.")
        }
    }
}

/// Always succeeds — for unit tests only.
struct GrantingRecordingPermissionGate: RecordingPermissionGating {
    func ensureAuthorizedForRecording() async -> RecordingAuthorizationState {
        .granted
    }
}

import AVFoundation
import Combine
import Foundation

@MainActor
final class SpeechCaptureManager: ObservableObject {
    enum Phase: Equatable {
        case idle
        case requestingPermission
        case recording
        case transcribing
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var latestTranscript: String = ""
    @Published private(set) var errorMessage: String?

    private let liveCapture: LiveSpeechCapturing
    private let permissionGate: any RecordingPermissionGating
    private let locale: Locale

    init(
        liveCapture: LiveSpeechCapturing? = nil,
        permissionGate: any RecordingPermissionGating = SystemRecordingPermissionGate(),
        locale: Locale = .current
    ) {
        self.liveCapture = liveCapture ?? LiveSpeechCaptureFactory.default()
        self.permissionGate = permissionGate
        self.locale = locale
    }

    var isBusy: Bool {
        switch phase {
        case .idle, .failed:
            return false
        case .requestingPermission, .recording, .transcribing:
            return true
        }
    }

    var canRecord: Bool {
        switch phase {
        case .idle, .failed:
            return true
        case .requestingPermission, .recording, .transcribing:
            return false
        }
    }

    var canCancel: Bool {
        switch phase {
        case .requestingPermission, .recording, .transcribing:
            return true
        case .idle, .failed:
            return false
        }
    }

    var isRecording: Bool {
        if case .recording = phase { return true }
        return false
    }

    func startRecording() {
        guard canRecord else { return }

        errorMessage = nil
        latestTranscript = ""

        Task { await startRecordingAsync() }
    }

    private func startRecordingAsync() async {
        phase = .requestingPermission

        switch await permissionGate.ensureAuthorizedForRecording() {
        case .denied(let message):
            errorMessage = message
            phase = .failed(message)
            return
        case .granted:
            break
        }

        do {
            try configureAudioSession()
            try await liveCapture.start(locale: locale) { [weak self] text in
                Task { @MainActor in
                    self?.latestTranscript = text
                }
            }
            phase = .recording
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            phase = .failed(message)
            try? await deactivateAudioSession()
        }
    }

    func stopRecording() {
        Task { await stopRecordingAsync() }
    }

    private func stopRecordingAsync() async {
        guard phase == .recording else { return }

        phase = .transcribing

        do {
            let finalFromStop = try await liveCapture.stop()
            let trimmedFinal = finalFromStop.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLatest = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmed = trimmedFinal.isEmpty ? trimmedLatest : trimmedFinal

            guard !trimmed.isEmpty else {
                let message = "No speech detected. Try again or type instead."
                errorMessage = message
                latestTranscript = ""
                phase = .failed(message)
                return
            }

            latestTranscript = trimmed
            errorMessage = nil
            phase = .idle
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            latestTranscript = ""
            phase = .failed(message)
        }
    }

    func cancelRecording() {
        liveCapture.cancel()
        errorMessage = nil
        latestTranscript = ""
        phase = .idle

        Task {
            try? await deactivateAudioSession()
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true, options: [])
    }

    private func deactivateAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

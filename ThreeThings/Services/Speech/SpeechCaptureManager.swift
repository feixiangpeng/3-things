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

    private let transcriber: any SpeechTranscribing
    private let permissionGate: any RecordingPermissionGating
    private let locale: Locale

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    init(
        transcriber: any SpeechTranscribing = DefaultSpeechTranscriber(),
        permissionGate: any RecordingPermissionGating = SystemRecordingPermissionGate(),
        locale: Locale = .current
    ) {
        self.transcriber = transcriber
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
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("three-things-voice-\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.prepareToRecord(), recorder.record() else {
                throw SpeechPipelineError.transcriptionFailed("Could not start audio recording.")
            }

            self.recordingURL = url
            self.recorder = recorder
            phase = .recording
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            phase = .failed(message)
        }
    }

    func stopRecording() {
        Task { await stopRecordingAsync() }
    }

    private func stopRecordingAsync() async {
        guard phase == .recording else { return }

        recorder?.stop()
        recorder = nil
        phase = .transcribing

        guard let url = recordingURL else {
            let message = "Recording file was missing."
            errorMessage = message
            phase = .failed(message)
            return
        }
        recordingURL = nil

        defer {
            try? FileManager.default.removeItem(at: url)
        }

        do {
            let text = try await transcriber.transcribe(audioFileAt: url, locale: locale)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else {
                let message = "No speech detected. Re-record or Type instead."
                errorMessage = message
                latestTranscript = ""
                phase = .failed(message)
                return
            }

            latestTranscript = trimmed
            errorMessage = nil
            phase = .idle
            try? await deactivateAudioSession()
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            latestTranscript = ""
            phase = .failed(message)
            try? await deactivateAudioSession()
        }
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
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

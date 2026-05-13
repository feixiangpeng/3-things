import AVFoundation
import Foundation
import Speech

/// Streaming speech-to-text used while the microphone is active (partial updates + final string on stop).
@MainActor
protocol LiveSpeechCapturing: AnyObject {
    func start(locale: Locale, onPartial: @escaping (String) -> Void) async throws
    func stop() async throws -> String
    func cancel()
}

// MARK: - Production (device)

/// `SFSpeechRecognizer` + `AVAudioEngine` tap for partial transcripts during recording.
@MainActor
final class SFSpeechLiveCapture: LiveSpeechCapturing {
    private let engine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var lastPartialText: String = ""

    func start(locale: Locale, onPartial: @escaping (String) -> Void) async throws {
        cancel()
        lastPartialText = ""

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechPipelineError.transcriptionFailed("Speech recognizer is not available for this locale.")
        }
        speechRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        engine.prepare()
        try engine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor in
                self.lastPartialText = text
                onPartial(text)
            }
        }
    }

    func stop() async throws -> String {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil

        try? await Task.sleep(nanoseconds: 120_000_000)

        try? await deactivateAudioSession()

        let trimmed = lastPartialText.trimmingCharacters(in: .whitespacesAndNewlines)
        lastPartialText = ""
        return trimmed
    }

    func cancel() {
        lastPartialText = ""
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil

        Task {
            try? await deactivateAudioSession()
        }
    }

    private func deactivateAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Simulator / tests

/// Emits scripted partial strings on a short timer; `stop()` returns the final transcript.
@MainActor
final class MockLiveSpeechCapture: LiveSpeechCapturing {
    private var partialScript: [String]
    private var finalTranscript: String
    private var emissionTasks: [Task<Void, Never>] = []

    init(partials: [String], finalTranscript: String) {
        self.partialScript = partials
        self.finalTranscript = finalTranscript
    }

    convenience init() {
        self.init(
            partials: ["Buy milk", "Buy milk and eggs"],
            finalTranscript: "Buy milk and eggs for the party."
        )
    }

    func start(locale: Locale, onPartial: @escaping (String) -> Void) async throws {
        cancelEmissions()
        for (index, text) in partialScript.enumerated() {
            let delay = UInt64(120_000_000 + 80_000_000 * UInt64(index))
            let task = Task {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    onPartial(text)
                }
            }
            emissionTasks.append(task)
        }
    }

    func stop() async throws -> String {
        cancelEmissions()
        return finalTranscript
    }

    func cancel() {
        cancelEmissions()
    }

    private func cancelEmissions() {
        emissionTasks.forEach { $0.cancel() }
        emissionTasks.removeAll()
    }
}

enum LiveSpeechCaptureFactory {
    @MainActor
    static func `default`() -> LiveSpeechCapturing {
        #if targetEnvironment(simulator)
        return MockLiveSpeechCapture()
        #else
        return SFSpeechLiveCapture()
        #endif
    }
}

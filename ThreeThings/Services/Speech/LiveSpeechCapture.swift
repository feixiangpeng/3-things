import AVFoundation
import Foundation
import Speech
import os

extension Notification.Name {
    /// Posted with `object: String` for DEBUG speech pipeline tracing (device builds).
    static let threeThingsSpeechPipelineDebug = Notification.Name("threeThingsSpeechPipelineDebug")
}

private let speechLog = Logger(subsystem: "com.ismaelrobles.threethings", category: "SpeechLive")

// MARK: - Audio level (RMS → normalized 0…1)

enum AudioLevelMeter {
    /// Maps microphone RMS to a Voice Memos–style normalized level (0 = silence, 1 = loud).
    static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let floatData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return 0 }

        var sumSquares: Double = 0
        var sampleCount = 0
        for channel in 0..<channelCount {
            let samples = floatData[channel]
            for frame in 0..<frameCount {
                let s = Double(samples[frame])
                sumSquares += s * s
                sampleCount += 1
            }
        }

        let rms = sqrt(sumSquares / Double(max(sampleCount, 1)))
        // dBFS for float samples in [-1, 1]
        let db = 20.0 * log10(max(rms, 1e-7))
        let quietDb = -55.0
        let loudDb = -12.0
        let t = (db - quietDb) / (loudDb - quietDb)
        return min(1, max(0, t))
    }
}

/// Streaming speech-to-text used while the microphone is active (partial updates + final string on stop).
protocol LiveSpeechCapturing: AnyObject, Sendable {
    func start(
        locale: Locale,
        onPartial: @MainActor @escaping (String) -> Void,
        onLevel: @MainActor @escaping (Double) -> Void
    ) async throws
    func stop() async throws -> String
    func cancel()
}

// MARK: - Production (device)

/// `SFSpeechRecognizer` + `AVAudioEngine` tap for partial transcripts during recording.
final class SFSpeechLiveCapture: LiveSpeechCapturing, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var lastPartialText: String = ""

    private var bufferAppendCount = 0
    private var partialCallbackCount = 0
    private var recognitionFinished = false
    private var lastRecognitionError: Error?

    func start(
        locale: Locale,
        onPartial: @MainActor @escaping (String) -> Void,
        onLevel: @MainActor @escaping (Double) -> Void
    ) async throws {
        resetCaptureState(shouldDeactivateAudioSession: false)
        lastPartialText = ""
        bufferAppendCount = 0
        partialCallbackCount = 0
        recognitionFinished = false
        lastRecognitionError = nil

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            emitDebug("SFSpeechRecognizer unavailable for locale \(locale.identifier)")
            throw SpeechPipelineError.transcriptionFailed("Speech recognizer is not available for this locale.")
        }
        speechRecognizer = recognizer
        emitDebug("recognizer ready locale=\(locale.identifier) onDevice=\(recognizer.supportsOnDeviceRecognition)")

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
            let level = AudioLevelMeter.normalizedLevel(from: buffer)
            Task { @MainActor in
                onLevel(level)
            }
        }

        engine.prepare()
        try engine.start()
        emitDebug("AVAudioEngine started")

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.emitDebug("recognition error: \(error.localizedDescription)")
                self.lastRecognitionError = error
                self.recognitionFinished = true
                return
            }

            guard let result else {
                self.emitDebug("recognition callback: nil result")
                return
            }

            let text = result.bestTranscription.formattedString
            self.lastPartialText = text
            self.partialCallbackCount += 1
            if self.partialCallbackCount <= 3 || self.partialCallbackCount % 15 == 0 {
                self.emitDebug("partial #\(self.partialCallbackCount) len=\(text.count) isFinal=\(result.isFinal)")
            }
            Task { @MainActor in
                onPartial(text)
            }

            if result.isFinal {
                self.emitDebug("recognition isFinal len=\(text.count)")
                self.recognitionFinished = true
            }
        }
    }

    func stop() async throws -> String {
        emitDebug("stop: begin")
        recognitionFinished = false
        lastRecognitionError = nil

        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }

        recognitionRequest?.endAudio()
        emitDebug("stop: endAudio sent; waiting for isFinal or timeout")

        let waitStart = Date()
        while !recognitionFinished, Date().timeIntervalSince(waitStart) < 3.0 {
            try await Task.sleep(nanoseconds: 35_000_000)
        }

        if !recognitionFinished {
            emitDebug("stop: timed out waiting for isFinal; using last partial (\(lastPartialText.count) chars)")
        }

        if let lastRecognitionError {
            let message = lastRecognitionError.localizedDescription
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            speechRecognizer = nil
            try? await deactivateAudioSession()
            emitDebug("stop: failing with error \(message)")
            throw SpeechPipelineError.transcriptionFailed(message)
        }

        let trimmed = lastPartialText.trimmingCharacters(in: .whitespacesAndNewlines)
        lastPartialText = ""

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil

        try? await Task.sleep(nanoseconds: 80_000_000)
        try? await deactivateAudioSession()

        emitDebug("stop: returning transcript len=\(trimmed.count)")
        return trimmed
    }

    func cancel() {
        emitDebug("cancel")
        resetCaptureState(shouldDeactivateAudioSession: true)
    }

    private func resetCaptureState(shouldDeactivateAudioSession: Bool) {
        lastPartialText = ""
        bufferAppendCount = 0
        partialCallbackCount = 0
        recognitionFinished = true
        lastRecognitionError = nil

        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil

        if shouldDeactivateAudioSession {
            Task {
                let session = AVAudioSession.sharedInstance()
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    private func deactivateAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func emitDebug(_ message: String) {
        speechLog.debug("\(message, privacy: .public)")
        #if DEBUG
        NotificationCenter.default.post(name: .threeThingsSpeechPipelineDebug, object: message)
        #endif
    }
}

// MARK: - Simulator / tests

/// Emits scripted partial strings on a short timer; `stop()` returns the final transcript.
final class MockLiveSpeechCapture: LiveSpeechCapturing, @unchecked Sendable {
    private var partialScript: [String]
    private let finalTranscript: String
    /// When true, `stop()` returns an empty string (exercises merge with last partial in `SpeechCaptureManager`).
    private let returnEmptyStringFromStop: Bool
    /// When set, `stop()` throws this error after optional empty-string behavior (tests only).
    private let throwOnStop: Error?
    /// Repeating normalized levels (0…1) for waveform tests; default mimics quiet→speech→decay.
    private let levelPattern: [Double]
    private var emissionTasks: [Task<Void, Never>] = []

    init(
        partials: [String],
        finalTranscript: String,
        returnEmptyStringFromStop: Bool = false,
        throwOnStop: Error? = nil,
        levelPattern: [Double]? = nil
    ) {
        self.partialScript = partials
        self.finalTranscript = finalTranscript
        self.returnEmptyStringFromStop = returnEmptyStringFromStop
        self.throwOnStop = throwOnStop
        self.levelPattern = levelPattern ?? [0.03, 0.06, 0.12, 0.28, 0.52, 0.45, 0.22, 0.1, 0.05, 0.04]
    }

    convenience init() {
        self.init(
            partials: ["Buy milk", "Buy milk and eggs"],
            finalTranscript: "Buy milk and eggs for the party."
        )
    }

    func start(
        locale: Locale,
        onPartial: @MainActor @escaping (String) -> Void,
        onLevel: @MainActor @escaping (Double) -> Void
    ) async throws {
        _ = locale
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

        let pattern = levelPattern
        let levelTask = Task {
            var index = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 55_000_000)
                guard !Task.isCancelled else { return }
                let value = pattern[index % pattern.count]
                index += 1
                await MainActor.run {
                    onLevel(value)
                }
            }
        }
        emissionTasks.append(levelTask)
    }

    func stop() async throws -> String {
        cancelEmissions()
        if let throwOnStop {
            throw throwOnStop
        }
        return returnEmptyStringFromStop ? "" : finalTranscript
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

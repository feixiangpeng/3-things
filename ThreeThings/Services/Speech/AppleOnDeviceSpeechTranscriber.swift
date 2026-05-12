import AVFoundation
import Foundation
import Speech

/// On-device transcription using `SpeechAnalyzer` + `SpeechTranscriber` (requires iOS 26 SDK / runtime).
struct AppleOnDeviceSpeechTranscriber: SpeechTranscribing {
    func transcribe(audioFileAt url: URL, locale: Locale) async throws -> String {
        let audioFile = try AVAudioFile(forReading: url)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        async let collected: String = collectTranscription(from: transcriber)

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        return try await collected
    }

    private func collectTranscription(from transcriber: SpeechTranscriber) async throws -> String {
        var output = ""
        for try await result in transcriber.results {
            output.append(contentsOf: result.text.characters)
        }
        return output
    }
}

/// Default app transcriber (on-device Apple stack).
struct DefaultSpeechTranscriber: SpeechTranscribing {
    private let inner = AppleOnDeviceSpeechTranscriber()

    func transcribe(audioFileAt url: URL, locale: Locale) async throws -> String {
        try await inner.transcribe(audioFileAt: url, locale: locale)
    }
}

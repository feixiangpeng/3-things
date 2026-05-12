import Foundation

/// Test / preview transcriber that does not touch microphone or Speech APIs.
struct MockSpeechTranscriber: SpeechTranscribing {
    private let outcome: Result<String, Error>
    private let delayNanoseconds: UInt64

    init(outcome: Result<String, Error>, delayNanoseconds: UInt64 = 0) {
        self.outcome = outcome
        self.delayNanoseconds = delayNanoseconds
    }

    init(transcript: String, delayNanoseconds: UInt64 = 0) {
        self.init(outcome: .success(transcript), delayNanoseconds: delayNanoseconds)
    }

    func transcribe(audioFileAt url: URL, locale: Locale) async throws -> String {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try outcome.get()
    }
}

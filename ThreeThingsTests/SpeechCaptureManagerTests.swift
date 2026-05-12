import XCTest
@testable import ThreeThings

@MainActor
final class SpeechCaptureManagerTests: XCTestCase {
    func testPermissionDeniedMovesToFailedWithMessage() async throws {
        struct Denying: RecordingPermissionGating {
            func ensureAuthorizedForRecording() async -> RecordingAuthorizationState {
                .denied(message: "Microphone blocked for tests.")
            }
        }

        let manager = SpeechCaptureManager(
            transcriber: MockSpeechTranscriber(transcript: "unused"),
            permissionGate: Denying()
        )

        manager.startRecording()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard case .failed(let message) = manager.phase else {
            XCTFail("Expected failed phase, got \(String(describing: manager.phase))")
            return
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("microphone"))
    }

    func testCancelClearsRecordingState() {
        let manager = SpeechCaptureManager(
            transcriber: MockSpeechTranscriber(transcript: "hello"),
            permissionGate: GrantingRecordingPermissionGate()
        )

        manager.cancelRecording()
        XCTAssertEqual(manager.phase, .idle)
        XCTAssertTrue(manager.latestTranscript.isEmpty)
        XCTAssertNil(manager.errorMessage)
    }
}

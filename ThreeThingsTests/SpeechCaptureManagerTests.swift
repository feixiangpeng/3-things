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
            liveCapture: MockLiveSpeechCapture(partials: [], finalTranscript: "unused"),
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
            liveCapture: MockLiveSpeechCapture(partials: [], finalTranscript: "hello"),
            permissionGate: GrantingRecordingPermissionGate()
        )

        manager.cancelRecording()
        XCTAssertEqual(manager.phase, .idle)
        XCTAssertTrue(manager.latestTranscript.isEmpty)
        XCTAssertNil(manager.errorMessage)
    }

    func testMockLiveCaptureEmitsPartialsBeforeFinal() async throws {
        let live = MockLiveSpeechCapture(
            partials: ["Buy milk", "Buy milk and eggs"],
            finalTranscript: "Buy milk and eggs for the party."
        )
        let manager = SpeechCaptureManager(
            liveCapture: live,
            permissionGate: GrantingRecordingPermissionGate()
        )

        manager.startRecording()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(manager.latestTranscript.contains("Buy milk"))

        manager.stopRecording()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(manager.phase, .idle)
        XCTAssertTrue(manager.latestTranscript.contains("party"))
    }

    /// When `SFSpeechRecognizer` returns an empty final string but partials were shown, keep the last partial (Beli stop/endAudio race mitigation path).
    func testStopReturnsEmptyStringFallsBackToLatestPartial() async throws {
        let live = MockLiveSpeechCapture(
            partials: ["One", "One two", "One two three"],
            finalTranscript: "One two three final.",
            returnEmptyStringFromStop: true
        )
        let manager = SpeechCaptureManager(
            liveCapture: live,
            permissionGate: GrantingRecordingPermissionGate()
        )

        manager.startRecording()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(manager.latestTranscript.contains("three"))

        manager.stopRecording()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(manager.phase, .idle)
        XCTAssertEqual(manager.latestTranscript, "One two three")
    }

    func testStopThrowsMapsToFailedPhase() async throws {
        let live = MockLiveSpeechCapture(
            partials: ["partial"],
            finalTranscript: "ignored",
            throwOnStop: SpeechPipelineError.transcriptionFailed("stop pipeline failed")
        )
        let manager = SpeechCaptureManager(
            liveCapture: live,
            permissionGate: GrantingRecordingPermissionGate()
        )

        manager.startRecording()
        try await Task.sleep(nanoseconds: 300_000_000)
        manager.stopRecording()
        try await Task.sleep(nanoseconds: 400_000_000)

        guard case .failed(let message) = manager.phase else {
            XCTFail("Expected failed phase, got \(String(describing: manager.phase))")
            return
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("stop pipeline"))
        XCTAssertTrue(manager.latestTranscript.isEmpty)
    }

    func testNoSpeechDetectedWhenStopAndPartialsEmpty() async throws {
        let live = MockLiveSpeechCapture(partials: [], finalTranscript: "")
        let manager = SpeechCaptureManager(
            liveCapture: live,
            permissionGate: GrantingRecordingPermissionGate()
        )

        manager.startRecording()
        try await Task.sleep(nanoseconds: 200_000_000)
        manager.stopRecording()
        try await Task.sleep(nanoseconds: 400_000_000)

        guard case .failed(let message) = manager.phase else {
            XCTFail("Expected failed phase, got \(String(describing: manager.phase))")
            return
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("no speech"))
    }
}

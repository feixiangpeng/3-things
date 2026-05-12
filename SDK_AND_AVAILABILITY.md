# Local voice stack — SDK & availability

This project targets **iOS 26+** so it can use:

| Capability | Apple API surface | Runtime checks |
|------------|-------------------|----------------|
| On-device speech-to-text | `Speech` — `SpeechAnalyzer`, `SpeechTranscriber`, preset **`.transcription`**, `analyzeSequence(from: AVAudioFile)` | `DefaultSpeechTranscriber` wraps `AppleOnDeviceSpeechTranscriber` (reads the recorded file via `AVAudioFile(forReading:)`). |
| On-device extraction | `FoundationModels` — `SystemLanguageModel`, `LanguageModelSession`, `@Generable` guided output | `FoundationModelsVoiceDraftExtractor` checks `SystemLanguageModel.default.isAvailable` and `supportsLocale(_:)` before prompting; otherwise throws `VoiceDraftExtractionError.modelUnavailable` / `localeUnsupported` (user gets **Type instead**). |
| Microphone + legacy speech auth | `AVAudioApplication.requestRecordPermission()`, `SFSpeechRecognizer.requestAuthorization` | `SystemRecordingPermissionGate`; failures map to `SpeechCaptureManager.Phase.failed` with a clear message. |

## Simulator vs device

- **Simulator (`targetEnvironment(simulator)`)**: `AppVoiceDraftExtractorFactory.default()` returns `HeuristicVoiceDraftExtractor` (deterministic, no Apple Intelligence required). `SpeechCaptureManager` still exercises permission + (when allowed) `AVAudioRecorder` + `SpeechAnalyzer` if the simulator supports it; transcription may fail — UI should surface **Type instead**.
- **Device**: factory uses `FoundationModelsVoiceDraftExtractor` for real guided generation.

## Tests

- Unit tests inject `HeuristicVoiceDraftExtractor()` into `AppViewModel` for stable extraction.
- `SpeechCaptureManagerTests` covers permission denial without touching hardware transcription.

## `xcodebuild` example

```bash
xcodebuild test -scheme "ThreeThings" -project "ThreeThings.xcodeproj" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1'
```

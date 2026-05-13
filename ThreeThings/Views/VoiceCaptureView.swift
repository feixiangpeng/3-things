import SwiftUI

struct VoiceCaptureView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var speechManager: SpeechCaptureManager
    /// When true, show a slimmer capture strip (e.g. while a draft already exists below).
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            if !compact {
                Text("Voice")
                    .font(.title3.bold())
            }

            statusView

            recordToggleRow

            if !speechManager.latestTranscript.isEmpty,
               speechManager.phase == .recording || speechManager.phase == .idle || speechManager.phase == .transcribing {
                Text(speechManager.latestTranscript)
                    .font(.footnote)
                    .themeCard(cornerRadius: 10, padding: 10)
            }

            if !compact {
                Button("Type instead") {
                    speechManager.cancelRecording()
                    viewModel.returnToTextEntry()
                }
                .buttonStyle(.borderless)
            } else {
                Button("Type instead") {
                    speechManager.cancelRecording()
                    viewModel.returnToTextEntry()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }

            if !viewModel.extractionStatus.isEmpty {
                Text(viewModel.extractionStatus)
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.muted)
            }

            #if DEBUG
            if !speechManager.speechDiagnosticLine.isEmpty {
                Text(speechManager.speechDiagnosticLine)
                    .font(.caption2.monospaced())
                    .foregroundStyle(ThemePalette.muted)
                    .themeCard(cornerRadius: 8, padding: 8)
            }
            #endif

#if DEBUG
            if !compact {
                DisclosureGroup("Eval fixtures (debug)") {
                    evalFixtureSection
                }
            }
#endif
        }
        .onChange(of: speechManager.latestTranscript) { _, newValue in
            viewModel.updateVoiceTranscriptSnapshot(newValue)
        }
        .onChange(of: speechManager.phase) { oldPhase, newPhase in
            viewModel.setVoiceRecordingActive(newPhase == .recording)
            if case .transcribing = oldPhase, case .idle = newPhase {
                Task {
                    await viewModel.flushLiveExtractionNow(transcript: speechManager.latestTranscript)
                }
            }
            if case .failed = newPhase {
                Task {
                    await viewModel.flushLiveExtractionNow(transcript: speechManager.latestTranscript)
                }
            }
        }
        .onAppear {
            viewModel.setVoiceRecordingActive(speechManager.isRecording)
        }
    }

    private var recordToggleRow: some View {
        let verticalPad: CGFloat = compact ? 10 : 14
        return HStack(spacing: 14) {
            if speechManager.phase == .recording {
                Button {
                    speechManager.stopRecording()
                } label: {
                    Label("Stop recording", systemImage: "stop.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(ThemeRecordingStopButtonStyle(verticalPadding: verticalPad))
                .disabled(speechManager.phase == .requestingPermission || speechManager.phase == .transcribing)
            } else {
                Button {
                    switch speechManager.phase {
                    case .idle, .failed:
                        viewModel.resetVoiceCustomizationForNewRecording()
                        speechManager.startRecording()
                    case .requestingPermission, .recording, .transcribing:
                        break
                    }
                } label: {
                    Label("Start speaking", systemImage: "mic.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(ThemePrimaryProminentButtonStyle(verticalPadding: verticalPad))
                .disabled(speechManager.phase == .requestingPermission || speechManager.phase == .transcribing)
            }

            if speechManager.canCancel, speechManager.phase == .recording {
                Button("Cancel", role: .cancel) {
                    speechManager.cancelRecording()
                }
                .font(.subheadline)
            }
        }
    }

#if DEBUG
    private var evalFixtureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Sample", selection: $viewModel.selectedVoiceFixtureID) {
                ForEach(viewModel.voiceFixtures) { fixture in
                    Text(fixture.title).tag(fixture.id)
                }
            }
            .pickerStyle(.menu)

            Text(viewModel.selectedVoiceFixture.transcript)
                .font(.footnote)
                .themeCard(cornerRadius: 10, padding: 10)

            Button("Generate draft from fixture") {
                viewModel.generateMockVoiceDraft()
            }
            .buttonStyle(ThemeSecondaryOutlineButtonStyle())
        }
    }
#endif

    @ViewBuilder
    private var statusView: some View {
        switch speechManager.phase {
        case .idle:
            if speechManager.errorMessage == nil, speechManager.latestTranscript.isEmpty {
                Text("Tap Start speaking, say your 1–3 things, then tap again to stop. Tasks update as you talk.")
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.muted)
            } else if let error = speechManager.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.overflow)
            } else {
                Text(viewModel.isExtracting ? "Updating your things…" : "Ready for more voice—or review below.")
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.muted)
            }
        case .requestingPermission:
            Text("Requesting microphone & speech access…")
                .font(.footnote)
                .foregroundStyle(ThemePalette.muted)
        case .recording:
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                Text("Listening… transcript updates live.")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(ThemePalette.primary)
        case .transcribing:
            HStack(spacing: 8) {
                ProgressView()
                Text("Finishing transcript…")
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.muted)
            }
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(ThemePalette.overflow)
        }
    }
}

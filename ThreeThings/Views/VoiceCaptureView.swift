import SwiftUI

enum VoiceCaptureLayout {
    /// Minimal home: centered circular record control and low-key type link.
    case home
    /// Full card with instructions and debug fixtures.
    case standard
    /// Slim strip when a voice draft already exists below.
    case compact
}

struct VoiceCaptureView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var speechManager: SpeechCaptureManager
    var layout: VoiceCaptureLayout = .standard
    var recordButtonDiameter: CGFloat = 100

    var body: some View {
        Group {
            switch layout {
            case .home:
                homeBody
            case .compact:
                compactBody
            case .standard:
                standardBody
            }
        }
        .modifier(VoiceCaptureChromeModifier(layout: layout))
        .onChange(of: speechManager.latestTranscript) { _, newValue in
            viewModel.updateVoiceTranscriptSnapshot(newValue)
        }
        .onChange(of: speechManager.phase) { _, newPhase in
            viewModel.setVoiceRecordingActive(newPhase == .recording)
        }
        .onAppear {
            viewModel.setVoiceRecordingActive(speechManager.isRecording)
            speechManager.onFinalTranscript = { [viewModel] transcript in
                Task {
                    await viewModel.ingestFinalTranscript(transcript)
                }
            }
        }
        .onDisappear {
            speechManager.onFinalTranscript = nil
        }
    }

    // MARK: - Home (minimal)

    private var homeBody: some View {
        VStack(spacing: 20) {
            homeStatusView

            if showsHomeWaveform {
                VoiceWaveformView(
                    level: speechManager.currentAudioLevel,
                    isRecording: speechManager.phase == .recording,
                    compact: true
                )
                .frame(height: 32)
            }

            homeRecordButton

            if speechManager.canCancel, speechManager.phase == .recording {
                Button("Cancel", role: .cancel) {
                    speechManager.cancelRecording()
                }
                .font(.caption)
                .foregroundStyle(ThemePalette.muted)
                .buttonStyle(.plain)
            }

            if homeShowsExtractionProgress {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating your things…")
                        .font(.caption)
                        .foregroundStyle(ThemePalette.muted)
                }
            }

            Button("Type instead") {
                speechManager.cancelRecording()
                viewModel.returnToTextEntry()
            }
            .font(.caption.weight(.medium))
            .buttonStyle(ThemeTealLinkButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var showsHomeWaveform: Bool {
        speechManager.phase == .recording || speechManager.phase == .transcribing
    }

    private var homeShowsExtractionProgress: Bool {
        viewModel.isExtracting
            && (speechManager.phase == .recording || speechManager.phase == .transcribing)
    }

    @ViewBuilder
    private var homeStatusView: some View {
        switch speechManager.phase {
        case .idle:
            if let error = speechManager.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.overflow)
                    .multilineTextAlignment(.center)
            }
        case .requestingPermission:
            Text("Requesting microphone access…")
                .font(.footnote)
                .foregroundStyle(ThemePalette.muted)
                .multilineTextAlignment(.center)
        case .recording:
            Text("Listening")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ThemePalette.primary)
        case .transcribing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(ThemePalette.primary)
                Text("Finishing…")
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.muted)
            }
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(ThemePalette.overflow)
                .multilineTextAlignment(.center)
        }
    }

    private var homeRecordButton: some View {
        Group {
            if speechManager.phase == .recording {
                Button {
                    speechManager.stopRecording()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(ThemeCircularRecordButtonStyle(isStop: true, diameter: recordButtonDiameter))
                .disabled(speechManager.phase == .transcribing)
                .accessibilityLabel("Stop recording")
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
                    Image(systemName: "mic.fill")
                }
                .buttonStyle(ThemeCircularRecordButtonStyle(diameter: recordButtonDiameter))
                .disabled(speechManager.phase == .requestingPermission || speechManager.phase == .transcribing)
                .accessibilityLabel("Start recording")
            }
        }
    }

    // MARK: - Compact (post-draft)

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusView(showIdleInstructions: false)

            VoiceWaveformView(
                level: speechManager.currentAudioLevel,
                isRecording: speechManager.phase == .recording,
                compact: true
            )

            standardRecordToggleRow(compact: true)

            if !speechManager.latestTranscript.isEmpty,
               speechManager.phase == .recording || speechManager.phase == .idle || speechManager.phase == .transcribing {
                Text(speechManager.latestTranscript)
                    .font(.footnote)
                    .foregroundStyle(Color.primary)
                    .themeCard(cornerRadius: 12, padding: 10)
            }

            if viewModel.isExtracting,
               !speechManager.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .center, spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Turning speech into your 1–3 things…")
                        .font(.footnote)
                        .foregroundStyle(ThemePalette.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Extracting tasks from transcript")
            }

            Button("Type instead") {
                speechManager.cancelRecording()
                viewModel.returnToTextEntry()
            }
            .font(.caption.weight(.medium))
            .buttonStyle(ThemeTealLinkButtonStyle())

            if !viewModel.extractionStatus.isEmpty {
                Text(viewModel.extractionStatus)
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.muted)
            }

            #if DEBUG
            if !speechManager.speechDiagnosticLine.isEmpty {
                speechDiagnosticBlock
            }
            #endif
        }
    }

    // MARK: - Standard (full card)

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice")
                .font(.title3.bold())
                .foregroundStyle(ThemePalette.primary)

            statusView(showIdleInstructions: true)

            VoiceWaveformView(
                level: speechManager.currentAudioLevel,
                isRecording: speechManager.phase == .recording,
                compact: false
            )

            standardRecordToggleRow(compact: false)

            if !speechManager.latestTranscript.isEmpty,
               speechManager.phase == .recording || speechManager.phase == .idle || speechManager.phase == .transcribing {
                Text(speechManager.latestTranscript)
                    .font(.footnote)
                    .foregroundStyle(Color.primary)
                    .themeCard(cornerRadius: 12, padding: 10)
            }

            if viewModel.isExtracting,
               !speechManager.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .center, spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Turning speech into your 1–3 things…")
                        .font(.footnote)
                        .foregroundStyle(ThemePalette.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Extracting tasks from transcript")
            }

            Button("Type instead") {
                speechManager.cancelRecording()
                viewModel.returnToTextEntry()
            }
            .font(.subheadline.weight(.medium))
            .buttonStyle(ThemeTealLinkButtonStyle())

            if !viewModel.extractionStatus.isEmpty {
                Text(viewModel.extractionStatus)
                    .font(.footnote)
                    .foregroundStyle(ThemePalette.muted)
            }

            #if DEBUG
            if !speechManager.speechDiagnosticLine.isEmpty {
                speechDiagnosticBlock
            }

            DisclosureGroup("Eval fixtures (debug)") {
                evalFixtureSection
            }
            .tint(ThemePalette.primary)
            #endif
        }
    }

    // MARK: - Shared

    private func standardRecordToggleRow(compact: Bool) -> some View {
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
                .foregroundStyle(ThemePalette.muted)
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
                .foregroundStyle(Color.primary)
                .themeCard(cornerRadius: 10, padding: 10)

            Button("Generate draft from fixture") {
                viewModel.generateMockVoiceDraft()
            }
            .buttonStyle(ThemeSecondaryOutlineButtonStyle())
        }
    }
#endif

    #if DEBUG
    private var speechDiagnosticBlock: some View {
        Text(speechManager.speechDiagnosticLine)
            .font(.caption2.monospaced())
            .foregroundStyle(ThemePalette.muted)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ThemePalette.inputFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ThemePalette.border.opacity(0.6), lineWidth: 1)
            )
    }
    #endif

    @ViewBuilder
    private func statusView(showIdleInstructions: Bool) -> some View {
        switch speechManager.phase {
        case .idle:
            if speechManager.errorMessage == nil, speechManager.latestTranscript.isEmpty {
                if showIdleInstructions {
                    Text("Tap Start speaking, say your 1–3 things, then tap again to stop. Tasks update as you talk.")
                        .font(.footnote)
                        .foregroundStyle(ThemePalette.muted)
                }
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                    Text("Listening… transcript updates live.")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(ThemePalette.primary)
                if viewModel.isExtracting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(ThemePalette.primary)
                        Text("Drafting tasks from what you've said so far…")
                            .font(.caption2)
                            .foregroundStyle(ThemePalette.muted)
                    }
                }
            }
        case .transcribing:
            HStack(alignment: .top, spacing: 8) {
                ProgressView()
                    .tint(ThemePalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Finishing transcript…")
                        .font(.footnote)
                        .foregroundStyle(ThemePalette.muted)
                    if viewModel.isExtracting {
                        Text("Still updating your draft from the last transcript.")
                            .font(.caption2)
                            .foregroundStyle(ThemePalette.muted)
                    }
                }
            }
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(ThemePalette.overflow)
        }
    }
}

// MARK: - Card chrome

private struct VoiceCaptureChromeModifier: ViewModifier {
    let layout: VoiceCaptureLayout

    func body(content: Content) -> some View {
        switch layout {
        case .home:
            content
        case .compact:
            content
                .themeSectionCard(cornerRadius: 14, padding: 12)
        case .standard:
            content
                .themeSectionCard(cornerRadius: 16, padding: 16)
        }
    }
}

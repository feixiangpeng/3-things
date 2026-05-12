import SwiftUI

struct VoiceCaptureView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var speechManager: SpeechCaptureManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice capture")
                .font(.title3.bold())

            statusView

            HStack(spacing: 12) {
                Button {
                    speechManager.startRecording()
                } label: {
                    Label("Record", systemImage: "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!speechManager.canRecord)

                Button {
                    speechManager.stopRecording()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(speechManager.phase != .recording)

                Button("Cancel", role: .cancel) {
                    speechManager.cancelRecording()
                }
                .disabled(!speechManager.canCancel)
            }

            if !speechManager.latestTranscript.isEmpty, speechManager.phase == .idle {
                Text(speechManager.latestTranscript)
                    .font(.footnote)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            Button {
                Task {
                    await viewModel.extractTasksFromTranscript(speechManager.latestTranscript)
                }
            } label: {
                if viewModel.isExtracting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Extract tasks")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                speechManager.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || speechManager.isBusy
                    || viewModel.isExtracting
            )

            Button("Type instead") {
                speechManager.cancelRecording()
                viewModel.returnToTextEntry()
            }
            .buttonStyle(.borderless)

            if !viewModel.extractionStatus.isEmpty {
                Text(viewModel.extractionStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

#if DEBUG
            DisclosureGroup("Eval fixtures (debug)") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Sample", selection: $viewModel.selectedVoiceFixtureID) {
                        ForEach(viewModel.voiceFixtures) { fixture in
                            Text(fixture.title).tag(fixture.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(viewModel.selectedVoiceFixture.transcript)
                        .font(.footnote)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

                    Button("Generate draft from fixture") {
                        viewModel.generateMockVoiceDraft()
                    }
                    .buttonStyle(.bordered)
                }
            }
#endif
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch speechManager.phase {
        case .idle:
            if speechManager.errorMessage == nil, speechManager.latestTranscript.isEmpty {
                Text("Tap Record, speak your 1–3 things, then Stop and Extract.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let error = speechManager.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("Transcript ready — tap Extract tasks.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .requestingPermission:
            Text("Requesting microphone & speech access…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .recording:
            Text("Recording…")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        case .transcribing:
            HStack(spacing: 8) {
                ProgressView()
                Text("Transcribing on device…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }
}

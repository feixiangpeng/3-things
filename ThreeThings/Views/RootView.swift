import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var speechManager = SpeechCaptureManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if viewModel.canEditPlan {
                        Picker("Input", selection: inputModeBinding) {
                            ForEach(InputMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if viewModel.selectedInputMode == .text {
                            TextCaptureView(viewModel: viewModel)
                        } else if viewModel.voiceDraft != nil {
                            ExtractionReviewView(viewModel: viewModel)
                        } else {
                            VoiceCaptureView(viewModel: viewModel, speechManager: speechManager)
                        }
                    } else {
                        LockedPlanView(viewModel: viewModel)
                    }
                }
                .padding(20)
            }
            .navigationTitle("3-things")
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.pendingFinalizationDayID != nil },
                set: { _ in }
            )
        ) {
            PendingFinalizationView(viewModel: viewModel)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(true)
        }
    }

    private var inputModeBinding: Binding<InputMode> {
        Binding(
            get: { viewModel.selectedInputMode },
            set: { mode in
                if mode == .text {
                    viewModel.returnToTextEntry()
                } else {
                    viewModel.selectedInputMode = .voice
                }
            }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.headline)
            Text("Momentum: \(viewModel.momentum7)/7")
                .font(.title2.bold())
            Text(viewModel.progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

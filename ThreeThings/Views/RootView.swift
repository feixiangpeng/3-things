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
                        if viewModel.selectedInputMode == .text {
                            textModeStack
                        } else {
                            voiceModeStack
                        }
                    } else {
                        LockedPlanView(viewModel: viewModel)
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(ThemePalette.background)
            .navigationTitle("3-things")
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Eval") {
                        VoiceExtractionEvalView()
                    }
                    .font(.caption)
                }
            }
            #endif
            .toolbarBackground(ThemePalette.background, for: .navigationBar)
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

    private var textModeStack: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                viewModel.switchToVoiceFromText()
            } label: {
                Label("Use voice instead", systemImage: "mic.fill")
            }
            .buttonStyle(ThemeSecondaryOutlineButtonStyle())

            TextCaptureView(viewModel: viewModel)
        }
    }

    private var voiceModeStack: some View {
        VStack(alignment: .leading, spacing: 20) {
            VoiceCaptureView(
                viewModel: viewModel,
                speechManager: speechManager,
                compact: viewModel.voiceDraft != nil
            )

            if viewModel.voiceDraft != nil {
                ExtractionReviewView(viewModel: viewModel)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.headline)
            Text("Momentum: \(viewModel.momentum7)/7")
                .font(.title2.bold())
            Text(viewModel.progressText)
                .font(.subheadline)
                .foregroundStyle(ThemePalette.muted)
        }
    }
}

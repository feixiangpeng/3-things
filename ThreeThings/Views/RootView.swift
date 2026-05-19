import SwiftUI

struct RootView: View {
    fileprivate static let rootScrollTopID = "rootScrollTop"

    @StateObject private var viewModel = AppViewModel()
    @StateObject private var speechManager = SpeechCaptureManager()

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        brandHeader
                            .id(RootView.rootScrollTopID)

                        header

                        if viewModel.canEditPlan {
                            if viewModel.selectedInputMode == .text {
                                textModeStack
                            } else {
                                voiceModeStack
                            }
                        } else {
                            LockedPlanView(viewModel: viewModel)
                                .themeSectionCard()
                        }
                    }
                    .padding(20)
                }
                .scrollContentBackground(.hidden)
                .themePageBackground()
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(ThemePalette.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .onChange(of: viewModel.scrollRootToTopToken) { _, _ in
                    withAnimation(.easeOut(duration: 0.28)) {
                        scrollProxy.scrollTo(RootView.rootScrollTopID, anchor: .top)
                    }
                }
                #if DEBUG
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink("Eval") {
                            VoiceExtractionEvalView()
                        }
                        .font(.caption)
                        .foregroundStyle(ThemePalette.primary)
                    }
                }
                #endif
            }
        }
        .preferredColorScheme(.light)
        .tint(ThemePalette.primary)
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

    private var brandHeader: some View {
        Text("3-things")
            .font(.title2.weight(.semibold))
            .foregroundStyle(ThemePalette.primary)
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
                .themeSectionCard()
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
                ExtractionReviewView(viewModel: viewModel, speechManager: speechManager)
                    .themeSectionCard()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ThemePalette.muted)
                .textCase(.uppercase)
                .tracking(0.6)
            Text("Momentum: \(viewModel.momentum7)/7")
                .font(.title2.bold())
                .foregroundStyle(Color.primary)
            Text(viewModel.progressText)
                .font(.subheadline)
                .foregroundStyle(ThemePalette.muted)
        }
    }
}

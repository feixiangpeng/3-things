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
                        topBanner
                            .id(RootView.rootScrollTopID)

                        if viewModel.canEditPlan {
                            if viewModel.selectedInputMode == .text {
                                textModeStack
                            } else if viewModel.voiceDraft != nil {
                                voiceDraftStack
                            } else {
                                minimalVoiceHome
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

    private var topBanner: some View {
        Text("3-things")
            .font(.largeTitle.bold())
            .foregroundStyle(ThemePalette.primary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    private var minimalVoiceHome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)
            VoiceCaptureView(
                viewModel: viewModel,
                speechManager: speechManager,
                layout: .home
            )
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 420)
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

    private var voiceDraftStack: some View {
        VStack(alignment: .leading, spacing: 20) {
            VoiceCaptureView(
                viewModel: viewModel,
                speechManager: speechManager,
                layout: .compact
            )

            ExtractionReviewView(viewModel: viewModel, speechManager: speechManager)
                .themeSectionCard()
        }
    }
}

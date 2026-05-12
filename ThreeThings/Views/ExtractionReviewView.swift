import SwiftUI

struct ExtractionReviewView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isShowingLockConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            selectedTasks
            extras
            validation
            actions
        }
        .confirmationDialog(
            "Lock today's things?",
            isPresented: $isShowingLockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Lock Today's Things", role: .destructive) {
                viewModel.confirmLockPlan()
            }

            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You cannot change these tasks after confirming. They stay locked until the next focus day at 2:00 AM local time.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.plan.detectedMoreThanThree ? "Pick what matters" : "Review voice draft")
                .font(.title3.bold())

            if viewModel.plan.detectedMoreThanThree {
                Text("I heard more than 3 things. Pick what actually matters today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let cleanedTranscript = viewModel.voiceDraft?.cleanedTranscript,
               !cleanedTranscript.isEmpty {
                Text(cleanedTranscript)
                    .font(.footnote)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var selectedTasks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(0..<3, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Thing \(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                viewModel.moveTask(from: index, to: index - 1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .disabled(index == 0)

                            Button {
                                viewModel.moveTask(from: index, to: index + 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .disabled(index == 2)
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }

                    TextField(
                        "What matters most?",
                        text: Binding(
                            get: { viewModel.plan.tasks[index].text },
                            set: { viewModel.updateTaskText(at: index, text: $0) }
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .overlay {
                        if viewModel.duplicateTaskIndexes.contains(index) {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.red, lineWidth: 1)
                        }
                    }

                    let count = viewModel.characterCount(at: index)
                    Text("\(count)/100")
                        .font(.caption2)
                        .foregroundStyle(count > 70 ? .orange : .secondary)
                }
            }
        }
    }

    private var extras: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !viewModel.plan.extras.isEmpty {
                Text("Extras")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(viewModel.plan.extras.enumerated()), id: \.offset) { index, extra in
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "Extra candidate",
                        text: Binding(
                            get: { extra },
                            set: { viewModel.updateExtraCandidate(at: index, text: $0) }
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack {
                        Menu("Replace selected") {
                            ForEach(0..<3, id: \.self) { selectedIndex in
                                Button("Thing \(selectedIndex + 1)") {
                                    viewModel.replaceSelectedTask(at: selectedIndex, withExtraAt: index)
                                }
                            }
                        }

                        Button("Discard") {
                            viewModel.discardExtraCandidate(at: index)
                        }
                        .foregroundStyle(.red)
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private var validation: some View {
        if let message = viewModel.taskValidationMessage {
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Lock Today's Things") {
                isShowingLockConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canPresentLockConfirmation)

            Button("Start Over With Typing") {
                viewModel.returnToTextEntry()
            }
            .buttonStyle(.bordered)
        }
    }
}

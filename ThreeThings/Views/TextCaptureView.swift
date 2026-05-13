import SwiftUI

struct TextCaptureView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isShowingLockConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose 1 to 3 things")
                .font(.title3.bold())

            ForEach(0..<3, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Thing \(index + 1)")
                            .font(.caption)
                            .foregroundStyle(ThemePalette.muted)

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
                        .foregroundStyle(ThemePalette.muted)
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
                                .stroke(ThemePalette.overflow, lineWidth: 1)
                        }
                    }

                    let count = viewModel.characterCount(at: index)
                    Text("\(count)/100")
                        .font(.caption2)
                        .foregroundStyle(count > 70 ? ThemePalette.warning : ThemePalette.muted)
                }
            }

            if let message = viewModel.taskValidationMessage {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ThemePalette.overflow)
            }

            Button("Lock Today's Things") {
                isShowingLockConfirmation = true
            }
            .buttonStyle(ThemePrimaryProminentButtonStyle())
            .disabled(!viewModel.canPresentLockConfirmation)

            Text("Lock when at least 1 task is ready (up to 3). Tasks lock until the next focus day at 2:00 AM local time.")
                .font(.footnote)
                .foregroundStyle(ThemePalette.muted)
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
}

import SwiftUI

struct TextCaptureView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isShowingLockConfirmation = false

    private var visibleSlotIndices: Range<Int> {
        0..<viewModel.textEntryVisibleSlotCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose 1 to 3 things")
                .font(.title3.bold())
                .foregroundStyle(ThemePalette.primary)

            ForEach(visibleSlotIndices, id: \.self) { index in
                taskField(index: index)
            }

            if viewModel.textEntryVisibleSlotCount < 3 {
                Button {
                    viewModel.revealNextTextTaskSlot()
                } label: {
                    Label("Add thing", systemImage: "plus")
                }
                .buttonStyle(ThemeTealOutlineCapsuleButtonStyle())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
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
        .onAppear {
            viewModel.syncTextEntryVisibleSlotsFromPlan()
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

    @ViewBuilder
    private func taskField(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Thing \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(ThemePalette.muted)

                Spacer()

                if viewModel.textEntryVisibleSlotCount > 1 {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.removeTextTask(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.body)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(ThemePalette.muted)
                        .accessibilityLabel("Remove thing \(index + 1)")

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
                            .disabled(index >= viewModel.textEntryVisibleSlotCount - 1)
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(ThemePalette.muted)
                    }
                }
            }

            TextField(
                "What matters most?",
                text: Binding(
                    get: { viewModel.plan.tasks[index].text },
                    set: { viewModel.updateTaskText(at: index, text: $0) }
                ),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(3...8)
            .themeInputField(cornerRadius: 12, isInvalid: viewModel.duplicateTaskIndexes.contains(index))

            let count = viewModel.characterCount(at: index)
            Text("\(count)/100")
                .font(.caption2)
                .foregroundStyle(count > 70 ? ThemePalette.warning : ThemePalette.muted)
        }
    }
}

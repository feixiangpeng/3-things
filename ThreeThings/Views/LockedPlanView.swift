import SwiftUI

struct LockedPlanView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Locked for today")
                .font(.title3.bold())

            Text("Locked until tomorrow at 2:00 AM.")
                .font(.footnote)
                .foregroundStyle(ThemePalette.muted)

            ForEach(viewModel.plan.tasks) { task in
                Button {
                    viewModel.toggleCompletion(taskID: task.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? ThemePalette.success : ThemePalette.muted)

                        Text(task.text.isEmpty ? "Untitled task" : task.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(.primary)
                    }
                    .themeCard()
                }
                .buttonStyle(.plain)
            }

            Text("\(viewModel.completedTaskCount)/\(viewModel.lockedTaskCount) complete")
                .font(.footnote)
                .foregroundStyle(ThemePalette.muted)

            if viewModel.completedTaskCount == viewModel.lockedTaskCount {
                Text("All locked tasks done.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ThemePalette.success)
            }
        }
    }
}

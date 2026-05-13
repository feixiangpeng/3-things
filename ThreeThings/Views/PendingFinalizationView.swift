import SwiftUI

struct PendingFinalizationView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Yesterday check-in")
                .font(.title3.bold())

            Text("Before setting today, did you complete yesterday's locked things?")
                .font(.body)

            HStack(spacing: 12) {
                Button("Done") {
                    viewModel.finalizePendingDay(completed: true)
                }
                .buttonStyle(.borderedProminent)

                Button("Not done") {
                    viewModel.finalizePendingDay(completed: false)
                }
                .buttonStyle(.bordered)
            }

            if let dayID = viewModel.pendingFinalizationDayID {
                Text("Pending day: \(dayID)")
                    .font(.caption)
                    .foregroundStyle(ThemePalette.muted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemePalette.background)
    }
}

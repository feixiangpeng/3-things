import SwiftUI

/// Full-screen dimmed picker: choose which plan slot an extra should replace, with a subtle jiggle on each row.
struct ReplaceThingPickerOverlay: View {
    let extraPreview: String
    let taskLines: [String]
    let onPick: (Int) -> Void
    let onCancel: () -> Void

    private var safeTaskLines: [String] {
        (0..<3).map { i in
            i < taskLines.count ? taskLines[i] : ""
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.35)
                .background(.thinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dimmed overlay")
                .accessibilityAddTraits(.isModal)
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Which thing should this replace?")
                        .font(.headline)
                        .foregroundStyle(ThemePalette.primary)

                    Text(previewDisplay(extraPreview))
                        .font(.subheadline)
                        .foregroundStyle(ThemePalette.muted)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Extra to swap in: \(previewDisplay(extraPreview))")

                    VStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { slot in
                            jiggleSlotButton(slot: slot, line: safeTaskLines[slot])
                        }
                    }
                    .padding(.top, 4)

                    Button("Cancel", action: onCancel)
                        .buttonStyle(ThemeSecondaryOutlineButtonStyle())
                        .padding(.top, 8)
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Closes replace picker without changing your plan")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ThemePalette.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ThemePalette.border.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    private func previewDisplay(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Empty extra" : t
    }

    @ViewBuilder
    private func jiggleSlotButton(slot: Int, line: String) -> some View {
        Button {
            onPick(slot)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text("Thing \(slot + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ThemePalette.muted)
                    .frame(width: 56, alignment: .leading)

                Text(rowDisplay(line))
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(ThemePalette.inputFill.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ThemePalette.border.opacity(0.85), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .modifier(JiggleWobbleModifier(slotIndex: slot))
        .accessibilityLabel("Replace thing \(slot + 1), currently \(rowDisplay(line)), with extra \(previewDisplay(extraPreview))")
        .accessibilityHint("Swaps this plan slot with the extra shown above")
    }

    private func rowDisplay(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Empty" : t
    }
}

// MARK: - Jiggle

private struct JiggleWobbleModifier: ViewModifier {
    let slotIndex: Int

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let omega = 2 * Double.pi / 0.42
            let stagger = Double(slotIndex) * 0.55
            let degrees = sin(t * omega + stagger) * 1.05
            content
                .rotationEffect(.degrees(degrees))
        }
    }
}

#Preview("Replace picker") {
    ZStack {
        ThemePalette.background.ignoresSafeArea()
        ReplaceThingPickerOverlay(
            extraPreview: "Pick up groceries and dry cleaning",
            taskLines: ["Morning run", "", "Call dentist"],
            onPick: { _ in },
            onCancel: {}
        )
    }
}

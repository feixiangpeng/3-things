import SwiftUI

/// Fixed bar meter: bar positions stay put; only heights follow the live level (0…1).
struct VoiceWaveformView: View {
    let level: CGFloat
    let isRecording: Bool
    var compact: Bool = false

    private var barCount: Int { compact ? 36 : 48 }
    private var trackHeight: CGFloat { compact ? 28 : 40 }

    /// Per-index multiplier (0.55…1) so the strip reads as an EQ while every bar tracks the same signal.
    private func shapeFactor(index: Int) -> CGFloat {
        let n = max(barCount, 2)
        let u = CGFloat(index) / CGFloat(n - 1)
        let d = abs(u - 0.5) * 2
        return 0.55 + 0.45 * (1 - d * d)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let barWidth = max(2, (width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let shaped = isRecording
                        ? min(1, max(0, level)) * shapeFactor(index: i)
                        : 0.04 * shapeFactor(index: i)
                    let minH: CGFloat = compact ? 3 : 4
                    let maxH = trackHeight - 4
                    let h = minH + (maxH - minH) * min(1, max(0, shaped))
                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(barColor(effectiveLevel: shaped))
                        .frame(width: barWidth, height: h)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.14), value: level)
            .animation(.easeOut(duration: 0.14), value: isRecording)
        }
        .frame(height: trackHeight)
        .accessibilityLabel(isRecording ? "Audio level meter" : "Audio level idle")
    }

    private func barColor(effectiveLevel: CGFloat) -> Color {
        if isRecording {
            return ThemePalette.primary.opacity(0.35 + Double(min(1, effectiveLevel)) * 0.65)
        }
        return ThemePalette.muted.opacity(0.35)
    }
}

#Preview("Waveform") {
    VoiceWaveformView(level: 0.55, isRecording: true, compact: false)
        .padding()
        .background(ThemePalette.cardFill)
}

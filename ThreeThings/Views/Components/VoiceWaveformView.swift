import SwiftUI

/// Voice Memos–style bar waveform driven by normalized microphone levels (0…1).
struct VoiceWaveformView: View {
    let samples: [CGFloat]
    let isRecording: Bool
    var compact: Bool = false

    private var barCount: Int { compact ? 36 : 48 }
    private var trackHeight: CGFloat { compact ? 28 : 40 }

    private var displayBars: [CGFloat] {
        let n = barCount
        if samples.count >= n {
            return Array(samples.suffix(n))
        }
        let pad = n - samples.count
        let baseline: CGFloat = 0.04
        return Array(repeating: baseline, count: pad) + samples
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let barWidth = max(2, (width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let level = displayBars[i]
                    let minH: CGFloat = compact ? 3 : 4
                    let maxH = trackHeight - 4
                    let h = minH + (maxH - minH) * min(1, max(0, level))
                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(barColor(for: level))
                        .frame(width: barWidth, height: h)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: trackHeight)
        .accessibilityLabel(isRecording ? "Audio level waveform" : "Audio level idle")
    }

    private func barColor(for level: CGFloat) -> Color {
        if isRecording {
            return ThemePalette.primary.opacity(0.35 + Double(min(1, level)) * 0.65)
        }
        return ThemePalette.muted.opacity(0.35)
    }
}

#Preview("Waveform") {
    VoiceWaveformView(
        samples: (0..<30).map { i in CGFloat(0.05 + 0.45 * sin(Double(i) * 0.35)) },
        isRecording: true,
        compact: false
    )
    .padding()
    .background(ThemePalette.cardFill)
}

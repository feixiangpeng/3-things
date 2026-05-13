import SwiftUI

/// Beli-inspired visual tokens (restaurant app: cream canvas, dark green brand, white cards, semantic traffic colors).
///
/// Asset-backed colors live in `Assets.xcassets` (`ThemePrimary`, `ThemeBackground`, …). Keep overflow/warning/success
/// reserved for meaning, not decoration.
enum ThemePalette {
    /// Dark forest green for primary actions and tint.
    static let primary = Color("ThemePrimary")
    /// Warm off-white / cream app canvas.
    static let background = Color("ThemeBackground")
    /// Card surfaces (typically white on cream).
    static let cardFill = Color("ThemeCardFill")
    static let border = Color("ThemeBorder")
    /// Secondary labels (muted olive-gray on light).
    static let muted = Color("ThemeMuted")
    static let success = Color("ThemeSuccess")
    static let warning = Color("ThemeWarning")
    static let overflow = Color("ThemeOverflow")
}

extension View {
    /// Card on neutral canvas with a light border (not frosted material).
    func themeCard(cornerRadius: CGFloat = 12, padding: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ThemePalette.cardFill, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ThemePalette.border, lineWidth: 1)
            )
    }
}

// MARK: - Button styles (avoid default `.borderedProminent` system blue on cream)

/// Primary CTA: white label on dark green fill.
struct ThemePrimaryProminentButtonStyle: ButtonStyle {
    var verticalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(
                ThemePalette.primary.opacity(configuration.isPressed ? 0.88 : 1.0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

/// Secondary: dark green stroke on cream, dark green text.
struct ThemeSecondaryOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ThemePalette.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ThemePalette.cardFill.opacity(configuration.isPressed ? 0.92 : 1.0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ThemePalette.primary.opacity(0.55), lineWidth: 1.5)
            )
    }
}

/// Stop recording: high-contrast semantic (white on overflow red).
struct ThemeRecordingStopButtonStyle: ButtonStyle {
    var verticalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(
                ThemePalette.overflow.opacity(configuration.isPressed ? 0.88 : 1.0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

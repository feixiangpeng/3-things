import SwiftUI

/// Beli-inspired visual tokens: warm cream canvas, deep **teal** brand, white cards, light input wells, semantic traffic colors.
///
/// Asset-backed colors live in `Assets.xcassets`. Dark luminosity variants were removed so the shell stays light on all
/// system appearances. Keep overflow/warning/success reserved for meaning, not decoration.
enum ThemePalette {
    /// Deep teal for primary actions, links, and brand emphasis (Beli-like blue-green).
    static let primary = Color("ThemePrimary")
    /// Warm off-white / cream app canvas (`#FBFAF5` range).
    static let background = Color("ThemeBackground")
    /// Card surfaces (white on cream).
    static let cardFill = Color("ThemeCardFill")
    static let border = Color("ThemeBorder")
    /// Light well behind text fields (Beli search-bar feel).
    static let inputFill = Color("ThemeInputFill")
    /// Secondary labels (warm gray on light).
    static let muted = Color("ThemeMuted")
    static let success = Color("ThemeSuccess")
    static let warning = Color("ThemeWarning")
    static let overflow = Color("ThemeOverflow")
}

extension View {
    /// Full-screen canvas behind scroll content.
    func themePageBackground() -> some View {
        background(ThemePalette.background.ignoresSafeArea())
    }

    /// Card on neutral canvas with a light border (Beli white card).
    func themeCard(cornerRadius: CGFloat = 12, padding: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ThemePalette.cardFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ThemePalette.border, lineWidth: 1)
            )
    }

    /// Larger section card (voice module, forms).
    func themeSectionCard(cornerRadius: CGFloat = 16, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ThemePalette.cardFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ThemePalette.border.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Text field (Beli pill / search well)

struct ThemeRoundedInputFieldModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var isInvalid: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ThemePalette.inputFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isInvalid ? ThemePalette.overflow : ThemePalette.border.opacity(0.85), lineWidth: isInvalid ? 1.5 : 1)
            )
    }
}

extension View {
    func themeInputField(cornerRadius: CGFloat = 12, isInvalid: Bool = false) -> some View {
        modifier(ThemeRoundedInputFieldModifier(cornerRadius: cornerRadius, isInvalid: isInvalid))
    }
}

// MARK: - Button styles (Beli teal fill / outline; avoid system blue)

private let beliCTACornerRadius: CGFloat = 14

/// Primary CTA: white label on deep teal fill, pill-like corners.
struct ThemePrimaryProminentButtonStyle: ButtonStyle {
    var verticalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(
                ThemePalette.primary.opacity(configuration.isPressed ? 0.82 : 1.0),
                in: RoundedRectangle(cornerRadius: beliCTACornerRadius, style: .continuous)
            )
    }
}

/// Secondary: teal stroke on white/cream, teal text.
struct ThemeSecondaryOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ThemePalette.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ThemePalette.cardFill.opacity(configuration.isPressed ? 0.94 : 1.0),
                in: RoundedRectangle(cornerRadius: beliCTACornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: beliCTACornerRadius, style: .continuous)
                    .stroke(ThemePalette.primary.opacity(0.45), lineWidth: 1.5)
            )
    }
}

/// Stop recording: semantic white on overflow red.
struct ThemeRecordingStopButtonStyle: ButtonStyle {
    var verticalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(
                ThemePalette.overflow.opacity(configuration.isPressed ? 0.88 : 1.0),
                in: RoundedRectangle(cornerRadius: beliCTACornerRadius, style: .continuous)
            )
    }
}

/// Inline teal text action (e.g. “Type instead”).
struct ThemeTealLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ThemePalette.primary.opacity(configuration.isPressed ? 0.65 : 1.0))
    }
}

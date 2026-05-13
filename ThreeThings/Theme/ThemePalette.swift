import SwiftUI

/// Dark green accent, neutral canvas; traffic colors reserved for meaning (success / caution / overflow).
enum ThemePalette {
    static let primary = Color("ThemePrimary")
    static let background = Color("ThemeBackground")
    static let cardFill = Color("ThemeCardFill")
    static let border = Color("ThemeBorder")
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

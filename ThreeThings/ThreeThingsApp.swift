import SwiftUI

@main
struct ThreeThingsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .tint(ThemePalette.primary)
        }
    }
}

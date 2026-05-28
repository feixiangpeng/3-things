import SwiftUI

@main
struct ThreeThingsApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationCoordinator.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .tint(ThemePalette.primary)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                NotificationCenter.default.post(name: .threeThingsAppDidBecomeActive, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let threeThingsAppDidBecomeActive = Notification.Name("threeThings.appDidBecomeActive")
}

import Foundation
import UserNotifications

enum PendingNotificationAction: Codable, Equatable {
    case openApp(kind: ReminderNotificationKind?)
    case eodYesAllDone(focusDayID: String)
    case eodNotQuite(focusDayID: String)
    case eodRemindLater(focusDayID: String)
}

@MainActor
final class NotificationCoordinator: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCoordinator()

    private let pendingActionKey = "threeThings.pendingNotificationAction"
    private let defaults: UserDefaults

    @MainActor var onPendingAction: ((PendingNotificationAction) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    func configure(center: UNUserNotificationCenter = .current()) {
        center.delegate = self
    }

    func consumePendingAction() -> PendingNotificationAction? {
        guard let data = defaults.data(forKey: pendingActionKey),
              let action = try? JSONDecoder().decode(PendingNotificationAction.self, from: data) else {
            return nil
        }
        defaults.removeObject(forKey: pendingActionKey)
        return action
    }

    func storePendingAction(_ action: PendingNotificationAction) {
        guard let data = try? JSONEncoder().encode(action) else { return }
        defaults.set(data, forKey: pendingActionKey)
        onPendingAction?(action)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let focusDayID = userInfo["focusDayID"] as? String
        let kindRaw = userInfo["kind"] as? String
        let kind = kindRaw.flatMap(ReminderNotificationKind.init(rawValue:))

        let action: PendingNotificationAction
        switch response.actionIdentifier {
        case NotificationAction.yesAllDone:
            guard let focusDayID else { return }
            action = .eodYesAllDone(focusDayID: focusDayID)
        case NotificationAction.notQuite:
            guard let focusDayID else { return }
            action = .eodNotQuite(focusDayID: focusDayID)
        case NotificationAction.remindLater:
            guard let focusDayID else { return }
            action = .eodRemindLater(focusDayID: focusDayID)
        default:
            action = .openApp(kind: kind)
        }

        await MainActor.run {
            self.storePendingAction(action)
        }
    }
}

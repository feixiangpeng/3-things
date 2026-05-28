import Foundation
import UserNotifications

protocol LocalNotificationScheduling: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorizationIfNeeded() async -> Bool
    func registerCategories() async
    func applySchedule(_ intents: [ScheduledNotificationIntent], activeFocusDayID: String) async
    func scheduleIntent(_ intent: ScheduledNotificationIntent) async
}

final class LocalNotificationService: LocalNotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func registerCategories() async {
        let yesAction = UNNotificationAction(
            identifier: NotificationAction.yesAllDone,
            title: "Yes, all done!",
            options: []
        )
        let notQuiteAction = UNNotificationAction(
            identifier: NotificationAction.notQuite,
            title: "Not quite",
            options: []
        )
        let remindLaterAction = UNNotificationAction(
            identifier: NotificationAction.remindLater,
            title: "Remind me later",
            options: []
        )

        let endOfDayCategory = UNNotificationCategory(
            identifier: NotificationCategory.endOfDay,
            actions: [yesAction, notQuiteAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )

        let setThingsCategory = UNNotificationCategory(
            identifier: NotificationCategory.setThings,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let progressCategory = UNNotificationCategory(
            identifier: NotificationCategory.progress,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([endOfDayCategory, setThingsCategory, progressCategory])
    }

    func applySchedule(_ intents: [ScheduledNotificationIntent], activeFocusDayID: String) async {
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending
            .map(\.identifier)
            .filter { identifier in
                identifier.hasPrefix("threeThings.")
                    && !identifier.hasPrefix(NotificationIdentifier.prefix(for: activeFocusDayID))
            }

        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        let activeIDs = Set(intents.map(\.identifier))
        let replaceIDs = pending
            .map(\.identifier)
            .filter { identifier in
                identifier.hasPrefix(NotificationIdentifier.prefix(for: activeFocusDayID))
                    && !activeIDs.contains(identifier)
                    && !identifier.contains(".eod.defer.")
            }

        if !replaceIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: replaceIDs)
        }

        for intent in intents {
            await scheduleIntent(intent)
        }
    }

    func scheduleIntent(_ intent: ScheduledNotificationIntent) async {
        let content = UNMutableNotificationContent()
        content.title = intent.title
        content.body = intent.body
        content.categoryIdentifier = intent.categoryIdentifier
        content.sound = .default
        content.userInfo = [
            "focusDayID": intent.focusDayID,
            "kind": intent.kind.rawValue
        ]

        let interval = max(1, intent.fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: intent.identifier, content: content, trigger: trigger)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }
}

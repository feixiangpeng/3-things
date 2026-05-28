import Foundation

enum ReminderNotificationKind: String, Codable, Equatable {
    case setThingsMorning
    case setThingsReminder
    case progressCheckIn
    case endOfDayReflection
    case endOfDayDeferral
}

struct ScheduledNotificationIntent: Equatable {
    let identifier: String
    let focusDayID: String
    let kind: ReminderNotificationKind
    let fireDate: Date
    let title: String
    let body: String
    let categoryIdentifier: String
    let completedCount: Int?
    let totalCount: Int?
}

enum NotificationCategory {
    static let setThings = "threeThings.setThings"
    static let progress = "threeThings.progress"
    static let endOfDay = "threeThings.endOfDay"
}

enum NotificationAction {
    static let yesAllDone = "threeThings.eod.yesAllDone"
    static let notQuite = "threeThings.eod.notQuite"
    static let remindLater = "threeThings.eod.remindLater"
}

enum NotificationIdentifier {
    static func morning(focusDayID: String) -> String {
        "threeThings.\(focusDayID).morning"
    }

    static func setReminder(focusDayID: String, index: Int) -> String {
        "threeThings.\(focusDayID).setReminder.\(index)"
    }

    static func progress(focusDayID: String, index: Int) -> String {
        "threeThings.\(focusDayID).progress.\(index)"
    }

    static func endOfDay(focusDayID: String) -> String {
        "threeThings.\(focusDayID).eod"
    }

    static func endOfDayDeferral(focusDayID: String, index: Int) -> String {
        "threeThings.\(focusDayID).eod.defer.\(index)"
    }

    static func prefix(for focusDayID: String) -> String {
        "threeThings.\(focusDayID)."
    }
}

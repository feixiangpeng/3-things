import Foundation

struct ReminderPreferences: Equatable, Codable {
    var startOfDayHour: Int
    var startOfDayMinute: Int
    var endOfDayHour: Int
    var endOfDayMinute: Int
    var reminderIntervalHours: Int
    var quietHoursStartHour: Int
    var quietHoursEndHour: Int
    var eodDeferralMinutes: Int
    var maxEODDeferrals: Int

    static let production = ReminderPreferences(
        startOfDayHour: 8,
        startOfDayMinute: 0,
        endOfDayHour: 21,
        endOfDayMinute: 0,
        reminderIntervalHours: 2,
        quietHoursStartHour: 22,
        quietHoursEndHour: 8,
        eodDeferralMinutes: 30,
        maxEODDeferrals: 2
    )

    #if DEBUG
    static let debugQA = ReminderPreferences(
        startOfDayHour: 8,
        startOfDayMinute: 0,
        endOfDayHour: 21,
        endOfDayMinute: 0,
        reminderIntervalHours: 1,
        quietHoursStartHour: 22,
        quietHoursEndHour: 8,
        eodDeferralMinutes: 2,
        maxEODDeferrals: 2
    )

    static let debugFastNotificationsKey = "threeThings.debugFastNotifications"
    #endif

    static var current: ReminderPreferences {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: debugFastNotificationsKey) {
            return .debugQA
        }
        #endif
        return .production
    }

    /// Quiet hours are inclusive of start hour and exclusive of end hour, except the start-of-day prompt at `quietHoursEndHour`.
    func isQuietHour(_ date: Date, calendar: Calendar = .autoupdatingCurrent, allowMorningPrompt: Bool) -> Bool {
        var calendar = calendar
        calendar.timeZone = .autoupdatingCurrent
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        if allowMorningPrompt,
           hour == quietHoursEndHour,
           minute == startOfDayMinute {
            return false
        }

        if quietHoursStartHour > quietHoursEndHour {
            return hour >= quietHoursStartHour || hour < quietHoursEndHour
        }

        return hour >= quietHoursStartHour && hour < quietHoursEndHour
    }
}

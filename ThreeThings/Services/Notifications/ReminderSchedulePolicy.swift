import Foundation

struct ReminderScheduleContext: Equatable {
    let now: Date
    let focusDayID: String
    let plan: DailyPlan
    let isCurrentDayFinalized: Bool
    let eodDeferralCount: Int
    let preferences: ReminderPreferences
}

struct ReminderScheduleResult: Equatable {
    let intents: [ScheduledNotificationIntent]
    let shouldAutoFinalizeComplete: Bool
}

enum ReminderSchedulePolicy {
    static func makeSchedule(for context: ReminderScheduleContext, calendar baseCalendar: Calendar = .autoupdatingCurrent) -> ReminderScheduleResult {
        var calendar = baseCalendar
        calendar.timeZone = .autoupdatingCurrent

        guard context.plan.focusDayID == context.focusDayID else {
            return ReminderScheduleResult(intents: [], shouldAutoFinalizeComplete: false)
        }

        guard !context.isCurrentDayFinalized else {
            return ReminderScheduleResult(intents: [], shouldAutoFinalizeComplete: false)
        }

        let lockedTasks = context.plan.tasks.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let completedCount = lockedTasks.filter(\.isCompleted).count
        let totalCount = max(lockedTasks.count, 1)
        let allComplete = context.plan.isLocked && !lockedTasks.isEmpty && lockedTasks.allSatisfy(\.isCompleted)

        if allComplete {
            return ReminderScheduleResult(intents: [], shouldAutoFinalizeComplete: true)
        }

        guard let focusDayDate = FocusDay.date(from: context.focusDayID, calendar: calendar) else {
            return ReminderScheduleResult(intents: [], shouldAutoFinalizeComplete: false)
        }

        let morningDate = calendar.date(
            bySettingHour: context.preferences.startOfDayHour,
            minute: context.preferences.startOfDayMinute,
            second: 0,
            of: focusDayDate
        )
        let endOfDayDate = calendar.date(
            bySettingHour: context.preferences.endOfDayHour,
            minute: context.preferences.endOfDayMinute,
            second: 0,
            of: focusDayDate
        )

        guard let morningDate, let endOfDayDate else {
            return ReminderScheduleResult(intents: [], shouldAutoFinalizeComplete: false)
        }

        var intents: [ScheduledNotificationIntent] = []

        if !context.plan.isLocked {
            if morningDate > context.now {
                intents.append(
                    ScheduledNotificationIntent(
                        identifier: NotificationIdentifier.morning(focusDayID: context.focusDayID),
                        focusDayID: context.focusDayID,
                        kind: .setThingsMorning,
                        fireDate: morningDate,
                        title: "Set your three things",
                        body: "What will you focus on today?",
                        categoryIdentifier: NotificationCategory.setThings,
                        completedCount: nil,
                        totalCount: nil
                    )
                )
            }

            let reminderDates = intervalDates(
                startingAt: morningDate,
                endingBefore: endOfDayDate,
                intervalHours: context.preferences.reminderIntervalHours,
                now: context.now,
                preferences: context.preferences,
                calendar: calendar,
                skipFirst: true
            )

            for (index, fireDate) in reminderDates.enumerated() {
                intents.append(
                    ScheduledNotificationIntent(
                        identifier: NotificationIdentifier.setReminder(focusDayID: context.focusDayID, index: index),
                        focusDayID: context.focusDayID,
                        kind: .setThingsReminder,
                        fireDate: fireDate,
                        title: "Still need your three things",
                        body: "Lock in 1–3 focus tasks for today.",
                        categoryIdentifier: NotificationCategory.setThings,
                        completedCount: nil,
                        totalCount: nil
                    )
                )
            }
        } else {
            let progressDates = intervalDates(
                startingAt: max(context.now, morningDate),
                endingBefore: endOfDayDate,
                intervalHours: context.preferences.reminderIntervalHours,
                now: context.now,
                preferences: context.preferences,
                calendar: calendar,
                skipFirst: false
            )

            for (index, fireDate) in progressDates.enumerated() {
                intents.append(
                    ScheduledNotificationIntent(
                        identifier: NotificationIdentifier.progress(focusDayID: context.focusDayID, index: index),
                        focusDayID: context.focusDayID,
                        kind: .progressCheckIn,
                        fireDate: fireDate,
                        title: "Focus check-in",
                        body: "Quick check: \(completedCount)/\(totalCount) done. Still focused?",
                        categoryIdentifier: NotificationCategory.progress,
                        completedCount: completedCount,
                        totalCount: totalCount
                    )
                )
            }

            if endOfDayDate > context.now, context.eodDeferralCount == 0 {
                intents.append(
                    ScheduledNotificationIntent(
                        identifier: NotificationIdentifier.endOfDay(focusDayID: context.focusDayID),
                        focusDayID: context.focusDayID,
                        kind: .endOfDayReflection,
                        fireDate: endOfDayDate,
                        title: "End-of-day reflection",
                        body: "Did you complete your locked things today?",
                        categoryIdentifier: NotificationCategory.endOfDay,
                        completedCount: completedCount,
                        totalCount: totalCount
                    )
                )
            }
        }

        return ReminderScheduleResult(intents: intents, shouldAutoFinalizeComplete: false)
    }

    static func makeDeferralIntent(
        focusDayID: String,
        deferralIndex: Int,
        now: Date,
        completedCount: Int,
        totalCount: Int,
        preferences: ReminderPreferences = .current
    ) -> ScheduledNotificationIntent? {
        guard deferralIndex < preferences.maxEODDeferrals else { return nil }

        guard let fireDate = Calendar.autoupdatingCurrent.date(
            byAdding: .minute,
            value: preferences.eodDeferralMinutes,
            to: now
        ) else {
            return nil
        }

        return ScheduledNotificationIntent(
            identifier: NotificationIdentifier.endOfDayDeferral(focusDayID: focusDayID, index: deferralIndex),
            focusDayID: focusDayID,
            kind: .endOfDayDeferral,
            fireDate: fireDate,
            title: "End-of-day reflection",
            body: "Did you complete your locked things today? (\(completedCount)/\(totalCount) done)",
            categoryIdentifier: NotificationCategory.endOfDay,
            completedCount: completedCount,
            totalCount: totalCount
        )
    }

    private static func intervalDates(
        startingAt start: Date,
        endingBefore end: Date,
        intervalHours: Int,
        now: Date,
        preferences: ReminderPreferences,
        calendar: Calendar,
        skipFirst: Bool
    ) -> [Date] {
        guard intervalHours > 0 else { return [] }

        var dates: [Date] = []
        var current = start

        if skipFirst {
            guard let next = calendar.date(byAdding: .hour, value: intervalHours, to: current) else {
                return []
            }
            current = next
        }

        while current < end {
            if current > now,
               !preferences.isQuietHour(current, calendar: calendar, allowMorningPrompt: false) {
                dates.append(current)
            }

            guard let next = calendar.date(byAdding: .hour, value: intervalHours, to: current) else {
                break
            }
            current = next
        }

        return dates
    }
}

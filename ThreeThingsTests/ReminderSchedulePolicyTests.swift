import XCTest
@testable import ThreeThings

final class ReminderSchedulePolicyTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
    }

    func testUnlockedMorningSchedulesStartPromptAndSetReminders() {
        let now = date(year: 2026, month: 4, day: 28, hour: 7)
        let focusDayID = FocusDay.id(for: now, calendar: calendar)
        let plan = DailyPlan.empty(for: focusDayID)

        let result = ReminderSchedulePolicy.makeSchedule(
            for: ReminderScheduleContext(
                now: now,
                focusDayID: focusDayID,
                plan: plan,
                isCurrentDayFinalized: false,
                eodDeferralCount: 0,
                preferences: .production
            ),
            calendar: calendar
        )

        XCTAssertFalse(result.shouldAutoFinalizeComplete)
        XCTAssertTrue(result.intents.contains { $0.kind == .setThingsMorning })
        XCTAssertTrue(result.intents.contains { $0.kind == .setThingsReminder })
        XCTAssertFalse(result.intents.contains { $0.kind == .progressCheckIn })
        XCTAssertFalse(result.intents.contains { $0.kind == .endOfDayReflection })
    }

    func testLockedIncompleteSchedulesProgressAndEndOfDay() {
        var plan = DailyPlan.empty(for: "2026-04-28")
        plan.isLocked = true
        plan.tasks = [
            TaskItem(text: "Write notes", sortOrder: 0),
            TaskItem(text: "Ship build", sortOrder: 1)
        ]

        let now = date(year: 2026, month: 4, day: 28, hour: 10)
        let result = ReminderSchedulePolicy.makeSchedule(
            for: ReminderScheduleContext(
                now: now,
                focusDayID: plan.focusDayID,
                plan: plan,
                isCurrentDayFinalized: false,
                eodDeferralCount: 0,
                preferences: .production
            ),
            calendar: calendar
        )

        XCTAssertTrue(result.intents.contains { $0.kind == .progressCheckIn })
        XCTAssertTrue(result.intents.contains { $0.kind == .endOfDayReflection })
        XCTAssertFalse(result.intents.contains { $0.kind == .setThingsReminder })
    }

    func testAllTasksCompleteRequestsAutoFinalize() {
        var plan = DailyPlan.empty(for: "2026-04-28")
        plan.isLocked = true
        plan.tasks = [
            TaskItem(text: "Write notes", isCompleted: true, sortOrder: 0)
        ]

        let result = ReminderSchedulePolicy.makeSchedule(
            for: ReminderScheduleContext(
                now: date(year: 2026, month: 4, day: 28, hour: 15),
                focusDayID: plan.focusDayID,
                plan: plan,
                isCurrentDayFinalized: false,
                eodDeferralCount: 0,
                preferences: .production
            ),
            calendar: calendar
        )

        XCTAssertTrue(result.shouldAutoFinalizeComplete)
        XCTAssertTrue(result.intents.isEmpty)
    }

    func testFinalizedDaySchedulesNothing() {
        var plan = DailyPlan.empty(for: "2026-04-28")
        plan.isLocked = true
        plan.tasks = [TaskItem(text: "Write notes", sortOrder: 0)]

        let result = ReminderSchedulePolicy.makeSchedule(
            for: ReminderScheduleContext(
                now: date(year: 2026, month: 4, day: 28, hour: 15),
                focusDayID: plan.focusDayID,
                plan: plan,
                isCurrentDayFinalized: true,
                eodDeferralCount: 0,
                preferences: .production
            ),
            calendar: calendar
        )

        XCTAssertFalse(result.shouldAutoFinalizeComplete)
        XCTAssertTrue(result.intents.isEmpty)
    }

    func testQuietHoursSkipSetReminders() {
        let focusDayID = "2026-04-28"
        let plan = DailyPlan.empty(for: focusDayID)
        let now = date(year: 2026, month: 4, day: 28, hour: 7)

        let result = ReminderSchedulePolicy.makeSchedule(
            for: ReminderScheduleContext(
                now: now,
                focusDayID: focusDayID,
                plan: plan,
                isCurrentDayFinalized: false,
                eodDeferralCount: 0,
                preferences: .production
            ),
            calendar: calendar
        )

        let reminderHours = result.intents
            .filter { $0.kind == .setThingsReminder }
            .map { calendar.component(.hour, from: $0.fireDate) }

        XCTAssertFalse(reminderHours.contains(23))
        XCTAssertFalse(reminderHours.contains(7))
    }

    func testDeferralIntentRespectsMaxCount() {
        let preferences = ReminderPreferences.production
        let intent = ReminderSchedulePolicy.makeDeferralIntent(
            focusDayID: "2026-04-28",
            deferralIndex: preferences.maxEODDeferrals,
            now: date(year: 2026, month: 4, day: 28, hour: 21, minute: 10),
            completedCount: 1,
            totalCount: 2,
            preferences: preferences
        )

        XCTAssertNil(intent)
    }

    func testDeferralIntentSchedulesFutureNotification() {
        let now = date(year: 2026, month: 4, day: 28, hour: 21, minute: 10)
        let intent = ReminderSchedulePolicy.makeDeferralIntent(
            focusDayID: "2026-04-28",
            deferralIndex: 0,
            now: now,
            completedCount: 1,
            totalCount: 2,
            preferences: .production
        )

        XCTAssertEqual(intent?.kind, .endOfDayDeferral)
        XCTAssertEqual(intent?.fireDate, date(year: 2026, month: 4, day: 28, hour: 21, minute: 40))
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}

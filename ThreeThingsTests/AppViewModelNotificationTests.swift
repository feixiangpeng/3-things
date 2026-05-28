import XCTest
import UserNotifications
@testable import ThreeThings

private final class MockLocalNotificationService: LocalNotificationScheduling, @unchecked Sendable {
    private(set) var lastIntents: [ScheduledNotificationIntent] = []
    private(set) var lastActiveFocusDayID: String?

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

    func requestAuthorizationIfNeeded() async -> Bool { true }

    func registerCategories() async {}

    func applySchedule(_ intents: [ScheduledNotificationIntent], activeFocusDayID: String) async {
        lastIntents = intents
        lastActiveFocusDayID = activeFocusDayID
    }

    func scheduleIntent(_ intent: ScheduledNotificationIntent) async {
        lastIntents.append(intent)
    }

    func resetRecordedIntents() {
        lastIntents = []
    }
}

@MainActor
final class AppViewModelNotificationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var mockScheduler: MockLocalNotificationService!
    private var coordinator: NotificationCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "AppViewModelNotificationTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        mockScheduler = MockLocalNotificationService()
        coordinator = NotificationCoordinator(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        mockScheduler = nil
        coordinator = nil
        try await super.tearDown()
    }

    func testLockingSchedulesProgressInsteadOfSetReminders() async {
        let now = localDate(year: 2026, month: 4, day: 28, hour: 9)
        let viewModel = makeViewModel(now: now)

        viewModel.updateTaskText(at: 0, text: "Write launch notes")
        await viewModel.refreshNotifications(reason: .bootstrap)

        XCTAssertTrue(mockScheduler.lastIntents.contains { $0.kind == .setThingsMorning || $0.kind == .setThingsReminder })

        viewModel.confirmLockPlan()
        await viewModel.refreshNotifications(reason: .lockPlan)

        XCTAssertFalse(mockScheduler.lastIntents.contains { $0.kind == .setThingsReminder })
        XCTAssertTrue(mockScheduler.lastIntents.contains { $0.kind == .progressCheckIn })
        XCTAssertTrue(mockScheduler.lastIntents.contains { $0.kind == .endOfDayReflection })
    }

    func testCompletingAllTasksAutoFinalizesDay() async {
        let now = localDate(year: 2026, month: 4, day: 28, hour: 15)
        let viewModel = makeViewModel(now: now)

        viewModel.updateTaskText(at: 0, text: "Write launch notes")
        viewModel.confirmLockPlan()
        viewModel.toggleCompletion(taskID: viewModel.plan.tasks[0].id)

        await viewModel.refreshNotifications(reason: .toggleCompletion)

        XCTAssertEqual(viewModel.momentum7, 1)
        XCTAssertTrue(mockScheduler.lastIntents.isEmpty)
    }

    func testEODYesAllDoneMarksTasksCompleteAndFinalizes() async {
        let now = localDate(year: 2026, month: 4, day: 28, hour: 21, minute: 5)
        let viewModel = makeViewModel(now: now)

        viewModel.updateTaskText(at: 0, text: "Write launch notes")
        viewModel.updateTaskText(at: 1, text: "Ship build")
        viewModel.confirmLockPlan()

        coordinator.storePendingAction(.eodYesAllDone(focusDayID: viewModel.plan.focusDayID))
        await viewModel.handleAppForegrounded()
        await viewModel.refreshNotifications(reason: .finalizeCurrentDay)

        XCTAssertTrue(viewModel.plan.tasks.allSatisfy(\.isCompleted))
        XCTAssertEqual(viewModel.momentum7, 1)
    }

    func testEODRemindLaterSchedulesDeferral() async {
        let now = localDate(year: 2026, month: 4, day: 28, hour: 21, minute: 5)
        let viewModel = makeViewModel(now: now)

        viewModel.updateTaskText(at: 0, text: "Write launch notes")
        viewModel.confirmLockPlan()
        await viewModel.refreshNotifications(reason: .bootstrap)
        mockScheduler.resetRecordedIntents()

        coordinator.storePendingAction(.eodRemindLater(focusDayID: viewModel.plan.focusDayID))
        await viewModel.handleAppForegrounded()

        XCTAssertTrue(mockScheduler.lastIntents.contains { $0.kind == .endOfDayDeferral })
    }

    func testEODRemindLaterCapsAtTwoDeferrals() async {
        let now = localDate(year: 2026, month: 4, day: 28, hour: 21, minute: 5)
        let viewModel = makeViewModel(now: now)

        viewModel.updateTaskText(at: 0, text: "Write launch notes")
        viewModel.confirmLockPlan()
        await viewModel.refreshNotifications(reason: .bootstrap)
        mockScheduler.resetRecordedIntents()

        coordinator.storePendingAction(.eodRemindLater(focusDayID: viewModel.plan.focusDayID))
        await viewModel.handleAppForegrounded()

        coordinator.storePendingAction(.eodRemindLater(focusDayID: viewModel.plan.focusDayID))
        await viewModel.handleAppForegrounded()

        let deferCount = mockScheduler.lastIntents.filter { $0.kind == .endOfDayDeferral }.count
        XCTAssertEqual(deferCount, 2)

        coordinator.storePendingAction(.eodRemindLater(focusDayID: viewModel.plan.focusDayID))
        await viewModel.handleAppForegrounded()

        XCTAssertEqual(mockScheduler.lastIntents.filter { $0.kind == .endOfDayDeferral }.count, 2)
    }

    private func makeViewModel(now: Date) -> AppViewModel {
        AppViewModel(
            defaults: defaults,
            dateProvider: { now },
            notificationScheduler: mockScheduler,
            notificationCoordinator: coordinator
        )
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    private func localDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = testCalendar
        components.timeZone = .autoupdatingCurrent
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return testCalendar.date(from: components)!
    }
}

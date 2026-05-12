import Foundation

enum PlanSource: String, Codable {
    case text
    case voice
}

struct DailyPlan: Codable, Equatable {
    var focusDayID: String
    var createdAt: Date
    var isLocked: Bool
    var source: PlanSource
    var tasks: [TaskItem]
    var extras: [String]
    var detectedMoreThanThree: Bool

    static func empty(for focusDayID: String) -> DailyPlan {
        DailyPlan(
            focusDayID: focusDayID,
            createdAt: Date(),
            isLocked: false,
            source: .text,
            tasks: [
                TaskItem(sortOrder: 0),
                TaskItem(sortOrder: 1),
                TaskItem(sortOrder: 2)
            ],
            extras: [],
            detectedMoreThanThree: false
        )
    }
}

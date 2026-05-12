import Foundation

struct TaskItem: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    var isCompleted: Bool
    var sortOrder: Int

    init(id: UUID = UUID(), text: String = "", isCompleted: Bool = false, sortOrder: Int) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
}

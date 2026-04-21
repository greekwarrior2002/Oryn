import SwiftData
import Foundation

@Model
final class Task {
    var id: UUID
    var title: String
    var deadline: Date
    var durationMinutes: Int
    var priorityRaw: Int
    var scheduledDate: Date?
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard !isCompleted else { return false }
        guard let scheduled = scheduledDate else { return false }
        return scheduled < Calendar.current.startOfDay(for: Date())
    }

    var deadlineIsToday: Bool {
        Calendar.current.isDateInToday(deadline)
    }

    var durationLabel: String {
        durationMinutes >= 60 ? "\(durationMinutes / 60)h" : "\(durationMinutes)m"
    }

    init(title: String, deadline: Date, durationMinutes: Int, priority: Priority) {
        self.id = UUID()
        self.title = title
        self.deadline = deadline
        self.durationMinutes = durationMinutes
        self.priorityRaw = priority.rawValue
        self.isCompleted = false
        self.createdAt = Date()
    }
}

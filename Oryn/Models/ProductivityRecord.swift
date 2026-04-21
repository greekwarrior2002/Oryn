import SwiftData
import Foundation

@Model final class ProductivityRecord {
    var id: UUID
    var taskId: UUID
    var taskTitle: String
    var completedAt: Date
    var scheduledForDate: Date
    var plannedMinutes: Int
    var energyLevelRaw: Int
    var priorityRaw: Int
    var sleepHours: Double
    var readinessScore: Int

    var completionHour: Int {
        Calendar.current.component(.hour, from: completedAt)
    }

    // true if the task was completed on the same day it was scheduled
    var wasOnTime: Bool {
        Calendar.current.isDate(completedAt, inSameDayAs: scheduledForDate)
    }

    init(task: OrynTask, sleepHours: Double, readinessScore: Int) {
        self.id = UUID()
        self.taskId = task.id
        self.taskTitle = task.title
        self.completedAt = task.completedAt ?? Date()
        self.scheduledForDate = task.scheduledDate ?? task.completedAt ?? Date()
        self.plannedMinutes = task.durationMinutes
        self.energyLevelRaw = task.energyLevelRaw
        self.priorityRaw = task.priorityRaw
        self.sleepHours = sleepHours
        self.readinessScore = readinessScore
    }
}

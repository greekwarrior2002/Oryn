import SwiftData
import Foundation

@Model
final class OrynTask {
    var id: UUID
    var title: String
    var deadline: Date
    var durationMinutes: Int
    var priorityRaw: Int
    var energyLevelRaw: Int
    var scheduledDate: Date?
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date

    // MARK: - Recurrence (schema V4)
    /// RecurrenceRule.rawValue; nil = no recurrence
    var recurrenceRuleRaw: String?
    /// Comma-separated Calendar.weekday ints for .custom rule, e.g. "2,4,6"
    var recurrenceCustomDaysRaw: String?
    /// Set on spawned occurrences to link back to the original task's id
    var parentRecurrenceId: UUID?

    // MARK: - Backlog / Inbox (schema V4)
    /// Stored as Bool? so lightweight migration can leave existing rows as nil (= false)
    var isBacklog: Bool?

    // MARK: - Manual Scheduling (schema V4)
    /// Scheduler must place the task on exactly this day
    var schedulePinnedDate: Date?
    /// Scheduler must not place the task before this day
    var scheduleNotBeforeDate: Date?
    /// When true, the task is skipped entirely during redistribution
    var isScheduleLocked: Bool?

    // MARK: - Computed: existing

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var energyLevel: EnergyLevel {
        get { EnergyLevel(rawValue: energyLevelRaw) ?? .medium }
        set { energyLevelRaw = newValue.rawValue }
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

    // MARK: - Computed: recurrence

    var recurrenceRule: RecurrenceRule? {
        get { recurrenceRuleRaw.flatMap { RecurrenceRule(rawValue: $0) } }
        set { recurrenceRuleRaw = newValue?.rawValue }
    }

    var recurrenceCustomDays: [Int] {
        get {
            guard let raw = recurrenceCustomDaysRaw else { return [] }
            return raw.split(separator: ",").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
        }
        set {
            recurrenceCustomDaysRaw = newValue.isEmpty
                ? nil
                : newValue.map(String.init).joined(separator: ",")
        }
    }

    /// Human-readable recurrence label for display, e.g. "Daily", "Mon · Wed · Fri"
    var recurrenceLabel: String? {
        guard let rule = recurrenceRule else { return nil }
        if rule == .custom {
            let days = recurrenceCustomDays
            let symbols = Calendar.current.veryShortWeekdaySymbols
            let names = days.compactMap { wd -> String? in
                guard wd >= 1, wd <= 7 else { return nil }
                return symbols[wd - 1]
            }
            return names.isEmpty ? "Custom" : names.joined(separator: " · ")
        }
        return rule.shortLabel
    }

    // MARK: - Computed: backlog / scheduling

    var isInBacklog: Bool {
        get { isBacklog ?? false }
        set { isBacklog = newValue ? true : nil }
    }

    var isLocked: Bool {
        get { isScheduleLocked ?? false }
        set { isScheduleLocked = newValue ? true : nil }
    }

    // MARK: - Init

    init(
        title: String,
        deadline: Date,
        durationMinutes: Int,
        priority: Priority,
        energyLevel: EnergyLevel = .medium,
        isBacklog: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.deadline = deadline
        self.durationMinutes = durationMinutes
        self.priorityRaw = priority.rawValue
        self.energyLevelRaw = energyLevel.rawValue
        self.isCompleted = false
        self.createdAt = Date()
        self.isBacklog = isBacklog ? true : nil
    }
}

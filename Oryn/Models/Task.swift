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
    /// Stored as Bool? so lightweight migration can leave existing rows as nil (= false).
    /// A task with isBacklog == true is an Inbox item — not placed on the calendar.
    var isBacklog: Bool?

    // MARK: - Manual Scheduling (schema V4)
    /// Scheduler must place the task on exactly this day
    var schedulePinnedDate: Date?
    /// Scheduler must not place the task before this day
    var scheduleNotBeforeDate: Date?
    /// When true, the task is skipped entirely during redistribution
    var isScheduleLocked: Bool?

    // MARK: - Inbox-first & parser metadata (schema V5)
    /// Wall-clock time component when the user (or parser) specified a specific time of day.
    /// Stored as a full Date whose hour/minute components are the intended time.
    var dueTime: Date?

    /// Whether the deadline/dueTime/priority were inferred from the title text.
    /// Used to show a subtle "inferred" hint and for analytics.
    var inferredFromTitleRaw: Bool?

    /// Origin of the task — "manual", "inbox", "outlook", "gcal", "suggestion", "scan", "siri".
    /// Defaults to "manual" when nil (pre-V5 rows).
    var sourceRaw: String?

    /// External identifier used by integrations to avoid duplicating imported items.
    var externalRef: String?

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

    // MARK: - Computed: V5 helpers

    var inferredFromTitle: Bool {
        get { inferredFromTitleRaw ?? false }
        set { inferredFromTitleRaw = newValue ? true : nil }
    }

    var source: TaskSource {
        get { TaskSource(rawValue: sourceRaw ?? "") ?? .manual }
        set { sourceRaw = newValue == .manual ? nil : newValue.rawValue }
    }

    /// Formatted time string for display (e.g. "7:00 PM"), or nil if no specific time.
    var dueTimeLabel: String? {
        guard let t = dueTime else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: t)
    }

    /// The canonical "when" date combining deadline day + dueTime if present.
    /// Useful for sorting today tasks chronologically.
    var deadlineWithTime: Date {
        guard let t = dueTime else { return deadline }
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: t)
        return cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: deadline) ?? deadline
    }

    // MARK: - Init

    init(
        title: String,
        deadline: Date,
        durationMinutes: Int,
        priority: Priority,
        energyLevel: EnergyLevel = .medium,
        isBacklog: Bool = false,
        dueTime: Date? = nil,
        inferredFromTitle: Bool = false,
        source: TaskSource = .manual,
        externalRef: String? = nil
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
        self.dueTime = dueTime
        self.inferredFromTitleRaw = inferredFromTitle ? true : nil
        self.sourceRaw = source == .manual ? nil : source.rawValue
        self.externalRef = externalRef
    }
}

// MARK: - TaskSource

enum TaskSource: String, Codable, CaseIterable {
    case manual      = "manual"
    case inbox       = "inbox"
    case outlook     = "outlook"
    case gcal        = "gcal"
    case suggestion  = "suggestion"
    case scan        = "scan"
    case siri        = "siri"

    var label: String {
        switch self {
        case .manual:     return "Added"
        case .inbox:      return "Inbox"
        case .outlook:    return "Outlook"
        case .gcal:       return "Google Calendar"
        case .suggestion: return "Suggested"
        case .scan:       return "Scanned"
        case .siri:       return "Siri"
        }
    }

    var icon: String {
        switch self {
        case .manual:     return "plus.circle"
        case .inbox:      return "tray.fill"
        case .outlook:    return "envelope.fill"
        case .gcal:       return "calendar.circle.fill"
        case .suggestion: return "sparkles"
        case .scan:       return "doc.text.viewfinder"
        case .siri:       return "mic.fill"
        }
    }
}

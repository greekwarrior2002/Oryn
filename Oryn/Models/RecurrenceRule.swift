import Foundation

enum RecurrenceRule: String, CaseIterable {
    case daily    = "daily"
    case weekly   = "weekly"
    case weekdays = "weekdays"
    case monthly  = "monthly"
    case custom   = "custom"

    var label: String {
        switch self {
        case .daily:    return "Every day"
        case .weekly:   return "Every week"
        case .weekdays: return "Weekdays (Mon–Fri)"
        case .monthly:  return "Every month"
        case .custom:   return "Custom days"
        }
    }

    var shortLabel: String {
        switch self {
        case .daily:    return "Daily"
        case .weekly:   return "Weekly"
        case .weekdays: return "Weekdays"
        case .monthly:  return "Monthly"
        case .custom:   return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .daily:    return "sun.max.fill"
        case .weekly:   return "calendar"
        case .weekdays: return "briefcase.fill"
        case .monthly:  return "calendar.badge.clock"
        case .custom:   return "slider.horizontal.3"
        }
    }

    /// Next occurrence date after the given completed date.
    /// customDays uses Calendar.weekday convention: 1=Sun, 2=Mon, …, 7=Sat.
    func nextOccurrence(after completedDate: Date, customDays: [Int] = []) -> Date? {
        let cal = Calendar.current
        switch self {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: completedDate)

        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: completedDate)

        case .weekdays:
            var next = cal.date(byAdding: .day, value: 1, to: completedDate)!
            for _ in 0..<7 {
                let wd = cal.component(.weekday, from: next)
                if wd >= 2 && wd <= 6 { return next }
                next = cal.date(byAdding: .day, value: 1, to: next)!
            }
            return nil

        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: completedDate)

        case .custom:
            guard !customDays.isEmpty else { return nil }
            var next = cal.date(byAdding: .day, value: 1, to: completedDate)!
            for _ in 0..<14 {
                let wd = cal.component(.weekday, from: next)
                if customDays.contains(wd) { return next }
                next = cal.date(byAdding: .day, value: 1, to: next)!
            }
            return nil
        }
    }
}

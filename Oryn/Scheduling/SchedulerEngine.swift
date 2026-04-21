import Foundation

struct SchedulerEngine {

    static let defaultDailyCapMinutes = 240 // 4 hours

    // MARK: - Main Scheduling

    /// Assigns a scheduledDate to every incomplete task.
    /// Sort order: priority high→low, then deadline earliest→latest.
    /// Fills each day up to dailyCapMinutes before moving forward.
    static func redistribute(tasks: [OrynTask], dailyCapMinutes: Int = defaultDailyCapMinutes) {
        let today = startOfDay(Date())

        let pending = tasks
            .filter { !$0.isCompleted }
            .sorted {
                if $0.priority.sortWeight != $1.priority.sortWeight {
                    return $0.priority.sortWeight > $1.priority.sortWeight
                }
                return $0.deadline < $1.deadline
            }

        // Seed the load map with already-completed tasks so their day slots stay counted
        var dayLoad: [Date: Int] = [:]

        for task in pending {
            let deadlineDay = startOfDay(task.deadline)
            var candidate = today
            var assigned = false

            for _ in 0..<365 {
                if candidate > deadlineDay {
                    // Can't fit before deadline — assign to deadline day regardless
                    task.scheduledDate = deadlineDay
                    dayLoad[deadlineDay, default: 0] += task.durationMinutes
                    assigned = true
                    break
                }
                let used = dayLoad[candidate, default: 0]
                if used + task.durationMinutes <= dailyCapMinutes {
                    task.scheduledDate = candidate
                    dayLoad[candidate, default: 0] += task.durationMinutes
                    assigned = true
                    break
                }
                candidate = nextDay(candidate)
            }

            if !assigned {
                task.scheduledDate = deadlineDay
            }
        }
    }

    // MARK: - Missed Task Recovery

    /// Called on app launch. Clears scheduledDate for any incomplete task
    /// assigned to a past day, then re-runs redistribution.
    static func rescheduleMissed(tasks: [OrynTask], dailyCapMinutes: Int = defaultDailyCapMinutes) {
        let today = startOfDay(Date())
        var didChange = false

        for task in tasks {
            guard !task.isCompleted,
                  let scheduled = task.scheduledDate,
                  scheduled < today else { continue }
            task.scheduledDate = nil
            didChange = true
        }

        if didChange {
            redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        }
    }

    // MARK: - "Too Busy Today"

    /// Clears scheduledDate for all incomplete tasks scheduled today,
    /// then redistributes starting from tomorrow.
    static func pushTodayForward(tasks: [OrynTask], dailyCapMinutes: Int = defaultDailyCapMinutes) {
        let today = startOfDay(Date())

        for task in tasks {
            guard !task.isCompleted,
                  let scheduled = task.scheduledDate,
                  Calendar.current.isDate(scheduled, inSameDayAs: today) else { continue }
            task.scheduledDate = nil
        }

        redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
    }

    // MARK: - "Done Early"

    /// Re-runs full distribution. Completed tasks free up capacity,
    /// so future tasks naturally move forward to fill today.
    static func pullForward(tasks: [OrynTask], dailyCapMinutes: Int = defaultDailyCapMinutes) {
        redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
    }

    // MARK: - Helpers

    static func minutesScheduled(on date: Date, tasks: [OrynTask]) -> Int {
        let day = startOfDay(date)
        return tasks
            .filter { !$0.isCompleted && $0.scheduledDate.map { startOfDay($0) == day } ?? false }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private static func nextDay(_ date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    }
}

import Foundation

struct SchedulerEngine {

    static let defaultDailyCapMinutes = 240 // 4 hours

    // MARK: - Main Scheduling

    /// Assigns a scheduledDate to every incomplete, unscheduled task.
    /// Sorts by priority (high first), then deadline (earliest first).
    /// Fills days up to dailyCapMinutes before moving to the next day.
    static func redistribute(tasks: [Task], dailyCapMinutes: Int = defaultDailyCapMinutes) {
        let today = startOfDay(Date())

        let pending = tasks
            .filter { !$0.isCompleted }
            .sorted {
                if $0.priority.sortWeight != $1.priority.sortWeight {
                    return $0.priority.sortWeight > $1.priority.sortWeight
                }
                return $0.deadline < $1.deadline
            }

        // Build a load map from already-completed tasks (their slots are taken)
        var dayLoad: [Date: Int] = [:]

        for task in pending {
            let deadlineDay = startOfDay(task.deadline)
            // Start scheduling from today, but never before today
            var candidate = today

            var assigned = false
            // Walk forward up to 365 days to find room
            for _ in 0..<365 {
                if candidate > deadlineDay {
                    // Can't fit before deadline — assign to deadline day anyway
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

            // Fallback: assign to deadline if loop exhausted
            if !assigned {
                task.scheduledDate = deadlineDay
            }
        }
    }

    // MARK: - Missed Task Recovery

    /// Called on app launch. Any incomplete task scheduled for a past day gets
    /// its scheduledDate cleared so redistribute can re-place it.
    static func rescheduleMissed(tasks: [Task], dailyCapMinutes: Int = defaultDailyCapMinutes) {
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

    /// Clears scheduledDate for all of today's incomplete tasks, then redistributes.
    /// Tasks are effectively pushed to the next available day.
    static func pushTodayForward(tasks: [Task], dailyCapMinutes: Int = defaultDailyCapMinutes) {
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

    /// Re-runs full distribution. Since completed tasks now free up today's capacity,
    /// pending tasks naturally get pulled forward.
    static func pullForward(tasks: [Task], dailyCapMinutes: Int = defaultDailyCapMinutes) {
        redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
    }

    // MARK: - Helpers

    static func minutesScheduled(on date: Date, tasks: [Task]) -> Int {
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

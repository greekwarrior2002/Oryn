import Foundation

struct SchedulerEngine {

    static let defaultDailyCapMinutes = 240 // 4 hours

    // MARK: - Main Scheduling

    /// Assigns a scheduledDate to every schedulable incomplete task.
    ///
    /// Rules:
    /// - Backlog tasks (isInBacklog) are skipped entirely — no scheduledDate assigned.
    /// - Locked tasks (isLocked) keep their current scheduledDate; their load is pre-seeded.
    /// - Pinned tasks (schedulePinnedDate != nil) are placed on that exact day.
    /// - notBeforeDate shifts the earliest candidate forward for a task.
    /// - Sort order: priority high→low, then deadline earliest→latest.
    /// - Fills each day to dailyCapMinutes before advancing.
    static func redistribute(
        tasks: [OrynTask],
        dailyCapMinutes: Int = defaultDailyCapMinutes,
        startFrom: Date? = nil
    ) {
        let today    = startOfDay(Date())
        let earliest = startFrom ?? today

        let pending = tasks
            .filter { !$0.isCompleted && !$0.isInBacklog && !$0.isLocked }
            .sorted {
                if $0.priority.sortWeight != $1.priority.sortWeight {
                    return $0.priority.sortWeight > $1.priority.sortWeight
                }
                return $0.deadline < $1.deadline
            }

        // Pre-seed completed work so their minutes count against each day's cap.
        var dayLoad: [Date: Int] = [:]
        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let day = startOfDay(completedAt)
                dayLoad[day, default: 0] += task.durationMinutes
            }
        }
        // Pre-seed locked tasks (they hold their slot during this redistribution).
        for task in tasks where !task.isCompleted && !task.isInBacklog && task.isLocked {
            if let scheduled = task.scheduledDate {
                let day = startOfDay(scheduled)
                dayLoad[day, default: 0] += task.durationMinutes
            }
        }

        for task in pending {
            let deadlineDay = startOfDay(task.deadline)

            // Pinned task: place directly on the pinned day regardless of capacity.
            if let pinned = task.schedulePinnedDate {
                let pinnedDay = startOfDay(pinned)
                task.scheduledDate = pinnedDay
                dayLoad[pinnedDay, default: 0] += task.durationMinutes
                continue
            }

            // notBeforeDate pushes the earliest eligible day forward.
            let notBefore = task.scheduleNotBeforeDate.map { max(earliest, startOfDay($0)) } ?? earliest
            var candidate = notBefore
            var assigned  = false

            for _ in 0..<365 {
                if candidate > deadlineDay {
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
        let today      = startOfDay(Date())
        var didChange  = false

        for task in tasks {
            guard !task.isCompleted,
                  !task.isInBacklog,
                  !task.isLocked,
                  task.schedulePinnedDate == nil,
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

    /// Moves all incomplete non-locked tasks scheduled today to tomorrow or later.
    /// Tasks whose deadline is today remain on today — they can't slip past their due date.
    static func pushTodayForward(tasks: [OrynTask], dailyCapMinutes: Int = defaultDailyCapMinutes) {
        let today    = startOfDay(Date())
        let tomorrow = nextDay(today)

        for task in tasks {
            guard !task.isCompleted,
                  !task.isInBacklog,
                  !task.isLocked,
                  task.schedulePinnedDate == nil,
                  let scheduled = task.scheduledDate,
                  Calendar.current.isDate(scheduled, inSameDayAs: today) else { continue }
            task.scheduledDate = nil
        }

        redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes, startFrom: tomorrow)
    }

    // MARK: - "Done Early"

    /// Re-runs full distribution. Completed tasks free up capacity,
    /// so future tasks naturally move forward to fill today.
    static func pullForward(tasks: [OrynTask], dailyCapMinutes: Int = defaultDailyCapMinutes) {
        redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
    }

    // MARK: - Adaptive Scheduling

    /// Adjusts today's capacity and task ordering based on the user's readiness score.
    static func adaptiveRedistribute(
        tasks: [OrynTask],
        dailyCapMinutes: Int = defaultDailyCapMinutes,
        readiness: ReadinessScore
    ) {
        switch readiness.level {
        case .medium:
            redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)

        case .low:
            let todayCap = Int(Double(dailyCapMinutes) * 0.65)
            let today    = startOfDay(Date())
            let tomorrow = nextDay(today)

            for task in tasks where !task.isCompleted && !task.isInBacklog && task.energyLevel == .high {
                let deadlineDay = startOfDay(task.deadline)
                task.scheduledDate = deadlineDay < tomorrow ? deadlineDay : tomorrow
            }

            redistributeWithOverride(
                tasks: tasks,
                dailyCapMinutes: dailyCapMinutes,
                todayCapOverride: todayCap,
                sortPredicate: { a, b in
                    if a.energyLevel.sortWeight != b.energyLevel.sortWeight {
                        return a.energyLevel.sortWeight < b.energyLevel.sortWeight
                    }
                    if a.priority.sortWeight != b.priority.sortWeight {
                        return a.priority.sortWeight > b.priority.sortWeight
                    }
                    return a.deadline < b.deadline
                }
            )

        case .high:
            let todayCap = Int(Double(dailyCapMinutes) * 1.2)
            redistributeWithOverride(
                tasks: tasks,
                dailyCapMinutes: dailyCapMinutes,
                todayCapOverride: todayCap,
                sortPredicate: { a, b in
                    if a.energyLevel.sortWeight != b.energyLevel.sortWeight {
                        return a.energyLevel.sortWeight > b.energyLevel.sortWeight
                    }
                    if a.priority.sortWeight != b.priority.sortWeight {
                        return a.priority.sortWeight > b.priority.sortWeight
                    }
                    return a.deadline < b.deadline
                }
            )
        }
    }

    @discardableResult
    private static func redistributeWithOverride(
        tasks: [OrynTask],
        dailyCapMinutes: Int,
        todayCapOverride: Int,
        sortPredicate: (OrynTask, OrynTask) -> Bool
    ) -> [Date: Int] {
        let today   = startOfDay(Date())
        let pending = tasks
            .filter { !$0.isCompleted && !$0.isInBacklog && !$0.isLocked }
            .sorted(by: sortPredicate)

        var dayLoad: [Date: Int] = [:]
        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let day = startOfDay(completedAt)
                dayLoad[day, default: 0] += task.durationMinutes
            }
        }
        for task in tasks where !task.isCompleted && !task.isInBacklog && task.isLocked {
            if let scheduled = task.scheduledDate {
                let day = startOfDay(scheduled)
                dayLoad[day, default: 0] += task.durationMinutes
            }
        }

        for task in pending {
            let deadlineDay = startOfDay(task.deadline)

            if let pinned = task.schedulePinnedDate {
                let pinnedDay = startOfDay(pinned)
                task.scheduledDate = pinnedDay
                dayLoad[pinnedDay, default: 0] += task.durationMinutes
                continue
            }

            let notBefore = task.scheduleNotBeforeDate.map { max(today, startOfDay($0)) } ?? today
            let earliest  = task.scheduledDate.map { max(notBefore, startOfDay($0)) } ?? notBefore
            var candidate = earliest
            var assigned  = false

            for _ in 0..<365 {
                if candidate > deadlineDay {
                    task.scheduledDate = deadlineDay
                    dayLoad[deadlineDay, default: 0] += task.durationMinutes
                    assigned = true
                    break
                }
                let cap  = Calendar.current.isDate(candidate, inSameDayAs: today)
                           ? todayCapOverride : dailyCapMinutes
                let used = dayLoad[candidate, default: 0]
                if used + task.durationMinutes <= cap {
                    task.scheduledDate = candidate
                    dayLoad[candidate, default: 0] += task.durationMinutes
                    assigned = true
                    break
                }
                candidate = nextDay(candidate)
            }
            if !assigned { task.scheduledDate = deadlineDay }
        }
        return dayLoad
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

    static func nextDay(_ date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    }
}

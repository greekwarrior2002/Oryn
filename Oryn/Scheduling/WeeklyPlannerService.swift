import Foundation

// MARK: - Weekly Plan Types

/// A single day bucket within a weekly plan. Carries enough context for the
/// Week view to render a useful, action-oriented row without re-querying the
/// task store.
struct WeekPlanDay: Identifiable {
    var id: Date { date }
    let date: Date
    let scheduled: [OrynTask]
    let completed: [OrynTask]
    let overdueCarry: [OrynTask]    // overdue tasks surfaced on their "should do next" day
    let capacityMinutes: Int        // user's daily cap
    let scheduledMinutes: Int
    let completedMinutes: Int

    var loadFraction: Double {
        guard capacityMinutes > 0 else { return 0 }
        return min(Double(scheduledMinutes + completedMinutes) / Double(capacityMinutes), 1.0)
    }

    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var isPast:  Bool { Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date()) }
    var isEmpty: Bool { scheduled.isEmpty && completed.isEmpty && overdueCarry.isEmpty }

    /// A compact label for the workload row ("1h 30m · 4 tasks").
    var loadSummary: String {
        if scheduled.isEmpty && completed.isEmpty { return "Free" }
        let total = scheduledMinutes + completedMinutes
        let h = total / 60, m = total % 60
        let timeLabel = h > 0 ? (m > 0 ? "\(h)h \(m)m" : "\(h)h") : "\(m)m"
        let count = scheduled.count + completed.count
        return "\(timeLabel) · \(count) task\(count == 1 ? "" : "s")"
    }
}

/// High-level summary of the week, used to drive the top "Plan" card.
struct WeekPlanSummary {
    let tasksThisWeek: Int          // total scheduled + completed in range
    let dueThisWeek: Int            // tasks with a deadline inside the range
    let overdueCount: Int           // tasks whose scheduledDate is < today
    let overloadedDays: [Date]      // days whose load >= 100%
    let freeDays: [Date]            // days with no scheduled work
    let completedThisWeek: Int

    var hasOverdue:     Bool { overdueCount > 0 }
    var hasOverloaded:  Bool { !overloadedDays.isEmpty }
    var hasFreeDays:    Bool { !freeDays.isEmpty }
}

/// Output of the planner — everything the Week view needs in one pass.
struct WeekPlan {
    let weekStart: Date
    let weekEnd: Date
    let days: [WeekPlanDay]
    let overdueTasks: [OrynTask]
    let priorities: [OrynTask]      // top 3 high-priority active items in range
    let summary: WeekPlanSummary
}

// MARK: - Weekly planner

/// Pure-logic helper that turns the raw task list into a week-view-ready plan.
///
/// Keeping this out of the view + off `TaskStore` means:
///   • SwiftUI's view code stays declarative — it just renders a `WeekPlan`.
///   • The planner is trivial to unit-test.
///   • Heavy filtering runs once per refresh, not per row.
enum WeeklyPlannerService {

    /// Build the plan for the week containing `anchor` (defaults to today).
    static func plan(
        for anchor: Date = Date(),
        tasks: [OrynTask],
        dailyCapMinutes: Int
    ) -> WeekPlan {
        let cal = Calendar.current
        let today = cal.startOfDay(for: anchor)

        // Rolling 7-day window starting today — "this week" in the action sense,
        // not the calendar-week sense. Users care about "what's next 7 days".
        guard let weekEnd = cal.date(byAdding: .day, value: 6, to: today) else {
            return empty(from: today)
        }

        // Build per-day buckets
        var days: [WeekPlanDay] = []
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let scheduled = tasks.filter { task in
                guard !task.isInBacklog, !task.isCompleted else { return false }
                guard let s = task.scheduledDate else { return false }
                return cal.isDate(s, inSameDayAs: day)
            }
            let completed = tasks.filter { task in
                guard task.isCompleted, let at = task.completedAt else { return false }
                return cal.isDate(at, inSameDayAs: day)
            }
            let scheduledMinutes = scheduled.reduce(0) { $0 + $1.durationMinutes }
            let completedMinutes = completed.reduce(0) { $0 + $1.durationMinutes }

            days.append(WeekPlanDay(
                date: day,
                scheduled: scheduled.sorted(by: dayOrder),
                completed: completed,
                overdueCarry: [],
                capacityMinutes: dailyCapMinutes,
                scheduledMinutes: scheduledMinutes,
                completedMinutes: completedMinutes
            ))
        }

        // Overdue: tasks with a scheduledDate before today and still not done.
        let overdue = tasks.filter { task in
            guard !task.isCompleted, !task.isInBacklog else { return false }
            guard let s = task.scheduledDate else { return false }
            return cal.startOfDay(for: s) < today
        }
        .sorted { (a, b) -> Bool in
            let ad = a.scheduledDate ?? .distantFuture
            let bd = b.scheduledDate ?? .distantFuture
            return ad < bd
        }

        // Top priorities: active tasks scheduled in window, sorted by priority
        // then deadline. This is what surfaces at the top of the week view.
        let priorities = tasks
            .filter { task in
                guard !task.isCompleted, !task.isInBacklog else { return false }
                guard let s = task.scheduledDate else { return false }
                let start = cal.startOfDay(for: s)
                return start >= today && start <= weekEnd
            }
            .sorted { (a, b) -> Bool in
                if a.priority.sortWeight != b.priority.sortWeight {
                    return a.priority.sortWeight > b.priority.sortWeight
                }
                return a.deadline < b.deadline
            }
            .prefix(3)
            .map { $0 }

        // Summary
        let totalScheduled = days.reduce(0) { $0 + $1.scheduled.count }
        let totalCompleted = days.reduce(0) { $0 + $1.completed.count }
        let overloaded = days.filter { $0.loadFraction >= 1.0 }.map(\.date)
        let free = days
            .filter { !$0.isPast && $0.scheduledMinutes == 0 && $0.completedMinutes == 0 }
            .map(\.date)
        let dueThisWeek = tasks.filter { task in
            guard !task.isCompleted, !task.isInBacklog else { return false }
            let day = cal.startOfDay(for: task.deadline)
            return day >= today && day <= weekEnd
        }.count

        let summary = WeekPlanSummary(
            tasksThisWeek: totalScheduled + totalCompleted,
            dueThisWeek: dueThisWeek,
            overdueCount: overdue.count,
            overloadedDays: overloaded,
            freeDays: free,
            completedThisWeek: totalCompleted
        )

        return WeekPlan(
            weekStart: today,
            weekEnd: weekEnd,
            days: days,
            overdueTasks: overdue,
            priorities: priorities,
            summary: summary
        )
    }

    // MARK: - Suggestions

    /// Recommends the best day to schedule a given backlog task based on the
    /// week's current workload. Picks the first non-overloaded day within the
    /// task's window that has spare capacity.
    ///
    /// Returns `nil` when every day is at capacity — the caller should fall
    /// back to the global scheduler in that case.
    static func suggestedDay(
        for task: OrynTask,
        in plan: WeekPlan
    ) -> Date? {
        let cal = Calendar.current
        let deadline = cal.startOfDay(for: task.deadline)
        for day in plan.days {
            guard day.date <= deadline else { continue }
            if day.isPast { continue }
            let remaining = day.capacityMinutes - (day.scheduledMinutes + day.completedMinutes)
            if remaining >= task.durationMinutes {
                return day.date
            }
        }
        // Fall back to earliest free day even if capacity is short
        return plan.days.first(where: { !$0.isPast && $0.scheduledMinutes == 0 })?.date
    }

    // MARK: - Private

    private static func empty(from today: Date) -> WeekPlan {
        WeekPlan(
            weekStart: today,
            weekEnd: today,
            days: [],
            overdueTasks: [],
            priorities: [],
            summary: WeekPlanSummary(
                tasksThisWeek: 0,
                dueThisWeek: 0,
                overdueCount: 0,
                overloadedDays: [],
                freeDays: [],
                completedThisWeek: 0
            )
        )
    }

    private static func dayOrder(_ a: OrynTask, _ b: OrynTask) -> Bool {
        if a.priority.sortWeight != b.priority.sortWeight {
            return a.priority.sortWeight > b.priority.sortWeight
        }
        if let at = a.dueTime, let bt = b.dueTime {
            return at < bt
        }
        return a.deadline < b.deadline
    }
}

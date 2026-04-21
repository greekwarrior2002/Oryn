import Foundation

// MARK: - Value-type snapshot of a ProductivityRecord
// Used to move computation off the main thread safely — SwiftData @Model objects
// must not be accessed from non-owning actors, so we copy the primitives first.

struct ProductivitySnapshot: Sendable {
    let completionHour: Int
    let sleepHours: Double
    let wasOnTime: Bool
    let completedAt: Date

    init(_ record: ProductivityRecord) {
        completionHour = record.completionHour
        sleepHours     = record.sleepHours
        wasOnTime      = record.wasOnTime
        completedAt    = record.completedAt
    }
}

// MARK: - Data Structures

struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
    let highlight: String?
    let type: InsightType
    let chartBars: [ChartBar]?
}

enum InsightType {
    case peak, sleep, consistency, energy, review, overload
}

struct ChartBar: Identifiable {
    let id = UUID()
    let label: String
    let value: Double       // 0.0–1.0 relative to the max bar
    let isHighlighted: Bool
}

// MARK: - Weekly Review Summary

struct WeeklyReviewSummary: Sendable {
    let completedCount: Int
    let onTimeCount: Int
    let slippedCount: Int
    let onTimeRatePct: Int
    let estimationAccuracyLabel: String?
    let weekStart: Date
    let weekEnd: Date

    var hasData: Bool { completedCount > 0 }
}

// MARK: - Productivity Summary (for AI service)

struct ProductivitySummary: Sendable {
    let totalCompletions: Int
    let daysTracked: Int
    let peakHour: Int?
    let onTimeRatePct: Int
    let currentStreak: Int
    let avgSleepHours: Double
    let sleepDataAvailable: Bool
    let eveningPct: Int
}

// MARK: - Engine

enum InsightsEngine {

    static let minimumCompletions = 3

    static func canGenerateInsights(from records: [ProductivityRecord]) -> Bool {
        records.count >= minimumCompletions
    }

    // Snapshot-based entry point — safe to call from any thread / actor.
    static func generateInsights(from snapshots: [ProductivitySnapshot]) -> [Insight] {
        guard !snapshots.isEmpty else { return [] }
        return [
            peakHoursInsight(from: snapshots),
            sleepInsight(from: snapshots),
            consistencyInsight(from: snapshots),
            eveningInsight(from: snapshots),
            overloadInsight(from: snapshots),
            estimationInsight(from: snapshots),
        ].compactMap { $0 }
    }

    static func buildSummary(from records: [ProductivityRecord]) -> ProductivitySummary {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        var blockCounts = [Int: Int]()
        for r in records { blockCounts[r.completionHour, default: 0] += 1 }
        let peakHour = blockCounts.max(by: { $0.value < $1.value })?.key

        let onTimeRate = records.isEmpty ? 0 :
            Int(Double(records.filter { $0.wasOnTime }.count) / Double(records.count) * 100)

        let sortedDays = Set(records.map { cal.startOfDay(for: $0.completedAt) }).sorted(by: >)
        var streak = 0
        var cursor = today
        for day in sortedDays {
            if cal.isDate(day, inSameDayAs: cursor) {
                streak += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
            } else if day < cursor { break }
        }

        let sleepRecords = records.filter { $0.sleepHours > 0 }
        let avgSleep = sleepRecords.isEmpty ? 0.0 :
            sleepRecords.reduce(0.0) { $0 + $1.sleepHours } / Double(sleepRecords.count)

        let eveningCount = records.filter { $0.completionHour >= 20 }.count
        let eveningPct   = records.isEmpty ? 0 :
            Int(Double(eveningCount) / Double(records.count) * 100)

        let daysTracked = Set(records.map { cal.startOfDay(for: $0.completedAt) }).count
        let peakBlock: Int? = peakHour.map { ($0 / 2) * 2 }

        return ProductivitySummary(
            totalCompletions: records.count,
            daysTracked: daysTracked,
            peakHour: peakBlock,
            onTimeRatePct: onTimeRate,
            currentStreak: streak,
            avgSleepHours: avgSleep,
            sleepDataAvailable: !sleepRecords.isEmpty,
            eveningPct: eveningPct
        )
    }

    // Convenience overload
    static func generateInsights(from records: [ProductivityRecord]) -> [Insight] {
        generateInsights(from: records.map(ProductivitySnapshot.init))
    }

    // MARK: - Weekly Review

    /// Builds a weekly review summary from records.
    /// Covers the last full Mon–Sun week; falls back to a rolling 7 days.
    static func weeklyReview(from snapshots: [ProductivitySnapshot]) -> WeeklyReviewSummary {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Rolling 7-day window
        let weekStart = cal.date(byAdding: .day, value: -6, to: today)!
        let weekEnd   = today

        let thisWeek = snapshots.filter {
            let day = cal.startOfDay(for: $0.completedAt)
            return day >= weekStart && day <= weekEnd
        }

        let completedCount = thisWeek.count
        let onTimeCount    = thisWeek.filter { $0.wasOnTime }.count
        let slippedCount   = thisWeek.filter { !$0.wasOnTime }.count
        let onTimeRatePct  = completedCount == 0 ? 0 :
            Int(Double(onTimeCount) / Double(completedCount) * 100)

        // Rough estimation accuracy label based on on-time rate
        let accuracyLabel: String?
        if completedCount >= 3 {
            switch onTimeRatePct {
            case 80...: accuracyLabel = "Good"
            case 60..<80: accuracyLabel = "Fair"
            default: accuracyLabel = "Needs work"
            }
        } else {
            accuracyLabel = nil
        }

        return WeeklyReviewSummary(
            completedCount: completedCount,
            onTimeCount: onTimeCount,
            slippedCount: slippedCount,
            onTimeRatePct: onTimeRatePct,
            estimationAccuracyLabel: accuracyLabel,
            weekStart: weekStart,
            weekEnd: weekEnd
        )
    }

    // MARK: - Peak Productivity Window

    static func peakHoursInsight(from snapshots: [ProductivitySnapshot]) -> Insight? {
        guard snapshots.count >= minimumCompletions else { return nil }

        var blockCounts = [Int: Int]()
        for s in snapshots {
            let block = (s.completionHour / 2) * 2
            blockCounts[block, default: 0] += 1
        }
        guard !blockCounts.isEmpty else { return nil }

        let best = blockCounts.max(by: { $0.value < $1.value })!
        guard Double(best.value) / Double(snapshots.count) >= 0.20 else { return nil }

        let maxCount   = Double(blockCounts.values.max() ?? 1)
        let chartBars: [ChartBar] = stride(from: 6, to: 22, by: 2).map { h in
            ChartBar(
                label: shortHourLabel(h),
                value: Double(blockCounts[h] ?? 0) / maxCount,
                isHighlighted: h == best.key
            )
        }

        return Insight(
            icon: "bolt.fill",
            title: "Peak Productivity",
            body: "You complete most tasks between \(hourLabel(best.key)) and \(hourLabel(best.key + 2)). Schedule your most important work here.",
            highlight: "\(hourLabel(best.key)) – \(hourLabel(best.key + 2))",
            type: .peak,
            chartBars: chartBars
        )
    }

    // MARK: - Sleep Impact

    static func sleepInsight(from snapshots: [ProductivitySnapshot]) -> Insight? {
        let withSleep = snapshots.filter { $0.sleepHours > 0 }
        guard withSleep.count >= 4 else { return nil }

        let cal = Calendar.current
        var dayData = [Date: (count: Int, sleep: Double)]()
        for s in withSleep {
            let day = cal.startOfDay(for: s.completedAt)
            if let existing = dayData[day] {
                dayData[day] = (count: existing.count + 1, sleep: s.sleepHours)
            } else {
                dayData[day] = (count: 1, sleep: s.sleepHours)
            }
        }
        guard dayData.count >= 3 else { return nil }

        let goodDays = dayData.values.filter { $0.sleep >= 7.0 }
        let poorDays = dayData.values.filter { $0.sleep < 6.0 }
        guard goodDays.count >= 1, poorDays.count >= 1 else { return nil }

        let avgGood = Double(goodDays.map(\.count).reduce(0, +)) / Double(goodDays.count)
        let avgPoor = Double(poorDays.map(\.count).reduce(0, +)) / Double(poorDays.count)
        guard avgPoor > 0, avgGood > avgPoor else { return nil }

        let uplift = Int(((avgGood - avgPoor) / avgPoor) * 100)
        return Insight(
            icon: "moon.fill",
            title: "Sleep & Focus",
            body: "On nights with 7+ hours of sleep, you complete around \(uplift)% more tasks. Rest is part of the plan.",
            highlight: "+\(uplift)% tasks",
            type: .sleep,
            chartBars: nil
        )
    }

    // MARK: - Consistency & Streaks

    static func consistencyInsight(from snapshots: [ProductivitySnapshot]) -> Insight? {
        guard snapshots.count >= minimumCompletions else { return nil }

        let cal     = Calendar.current
        let today   = cal.startOfDay(for: Date())
        let sortedDays = Set(snapshots.map { cal.startOfDay(for: $0.completedAt) }).sorted(by: >)

        var streak = 0
        var cursor = today
        for day in sortedDays {
            if cal.isDate(day, inSameDayAs: cursor) {
                streak += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
            } else if day < cursor { break }
        }

        if streak >= 3 {
            return Insight(
                icon: "flame.fill",
                title: "On a Roll",
                body: "You've completed tasks \(streak) days in a row. Momentum is building.",
                highlight: "\(streak)-day streak",
                type: .consistency,
                chartBars: nil
            )
        }

        let onTimeRate = Int(Double(snapshots.filter { $0.wasOnTime }.count) / Double(snapshots.count) * 100)

        if onTimeRate >= 70 {
            return Insight(
                icon: "checkmark.circle.fill",
                title: "Great Follow-Through",
                body: "\(onTimeRate)% of your tasks get done on their scheduled day. You plan and deliver.",
                highlight: "\(onTimeRate)% on time",
                type: .consistency,
                chartBars: nil
            )
        }

        if snapshots.count >= 8 && onTimeRate < 50 {
            let slipRate = 100 - onTimeRate
            return Insight(
                icon: "calendar.badge.clock",
                title: "Slippage Pattern",
                body: "About \(slipRate)% of tasks shift to a later day. Your estimates may be optimistic — try scheduling a bit less each day.",
                highlight: "\(slipRate)% rescheduled",
                type: .consistency,
                chartBars: nil
            )
        }

        let tasksWord = snapshots.count == 1 ? "task" : "tasks"
        return Insight(
            icon: "chart.line.uptrend.xyaxis",
            title: "Building Momentum",
            body: "You've completed \(snapshots.count) \(tasksWord) across \(sortedDays.count) day(s). Keep going — patterns emerge with more data.",
            highlight: "\(snapshots.count) done",
            type: .consistency,
            chartBars: nil
        )
    }

    // MARK: - Evening Pattern

    static func eveningInsight(from snapshots: [ProductivitySnapshot]) -> Insight? {
        guard snapshots.count >= 6 else { return nil }
        let evening = snapshots.filter { $0.completionHour >= 20 }
        let rate = Double(evening.count) / Double(snapshots.count)
        guard rate > 0.20 else { return nil }

        let pct = Int(rate * 100)
        return Insight(
            icon: "moon.stars.fill",
            title: "Late-Night Pattern",
            body: "\(pct)% of your tasks get done after 8 PM. Try saving lighter tasks for evenings and protecting earlier hours for focused work.",
            highlight: "\(pct)% after 8 PM",
            type: .energy,
            chartBars: nil
        )
    }

    // MARK: - Schedule Overload

    /// Fires when the user consistently slips more than 60% of tasks — a sign of over-scheduling.
    static func overloadInsight(from snapshots: [ProductivitySnapshot]) -> Insight? {
        guard snapshots.count >= 10 else { return nil }

        // Look at recent 14 days
        let cal      = Calendar.current
        let cutoff   = cal.date(byAdding: .day, value: -14, to: Date())!
        let recent   = snapshots.filter { $0.completedAt >= cutoff }
        guard recent.count >= 5 else { return nil }

        let onTime   = recent.filter { $0.wasOnTime }.count
        let slipRate = 1.0 - (Double(onTime) / Double(recent.count))
        guard slipRate > 0.60 else { return nil }

        let slipPct = Int(slipRate * 100)
        return Insight(
            icon: "exclamationmark.triangle.fill",
            title: "Schedule Overload",
            body: "\(slipPct)% of your recent tasks are slipping to later days. Consider reducing your daily limit or breaking tasks into smaller chunks.",
            highlight: "\(slipPct)% slipping",
            type: .overload,
            chartBars: nil
        )
    }

    // MARK: - Estimation Accuracy

    /// Positive signal when the user consistently completes tasks on the scheduled day.
    static func estimationInsight(from snapshots: [ProductivitySnapshot]) -> Insight? {
        guard snapshots.count >= 8 else { return nil }

        let onTimeRate = Int(Double(snapshots.filter { $0.wasOnTime }.count) / Double(snapshots.count) * 100)

        // Only surface this if the existing consistency insight wouldn't already cover it
        guard onTimeRate >= 80 else { return nil }

        return Insight(
            icon: "target",
            title: "Accurate Estimates",
            body: "You complete \(onTimeRate)% of tasks on the day you schedule them. Your planning instincts are well-calibrated.",
            highlight: "\(onTimeRate)% on target",
            type: .consistency,
            chartBars: nil
        )
    }

    // MARK: - Helpers

    static func hourLabel(_ hour: Int) -> String {
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return hour < 12 ? "\(h) AM" : "\(h) PM"
    }

    private static func shortHourLabel(_ hour: Int) -> String {
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return hour < 12 ? "\(h)a" : "\(h)p"
    }
}

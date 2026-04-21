import Foundation

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
    case peak, sleep, consistency, energy
}

struct ChartBar: Identifiable {
    let id = UUID()
    let label: String
    let value: Double       // 0.0–1.0 relative to the max bar
    let isHighlighted: Bool
}

// MARK: - Engine

enum InsightsEngine {
    static let minimumCompletions = 5

    static func canGenerateInsights(from records: [ProductivityRecord]) -> Bool {
        records.count >= minimumCompletions
    }

    static func generateInsights(from records: [ProductivityRecord]) -> [Insight] {
        guard !records.isEmpty else { return [] }
        return [
            peakHoursInsight(from: records),
            sleepInsight(from: records),
            consistencyInsight(from: records),
            eveningInsight(from: records),
        ].compactMap { $0 }
    }

    // MARK: - Peak Productivity Window

    static func peakHoursInsight(from records: [ProductivityRecord]) -> Insight? {
        guard records.count >= minimumCompletions else { return nil }

        // Group completions into 2-hour blocks (6 AM – 10 PM)
        var blockCounts = [Int: Int]()
        for record in records {
            let block = (record.completionHour / 2) * 2
            blockCounts[block, default: 0] += 1
        }
        guard blockCounts.count >= 2 else { return nil }

        let best = blockCounts.max(by: { $0.value < $1.value })!
        // Only surface this if the peak block holds ≥20 % of all completions
        guard Double(best.value) / Double(records.count) >= 0.20 else { return nil }

        let maxCount = Double(blockCounts.values.max() ?? 1)
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

    static func sleepInsight(from records: [ProductivityRecord]) -> Insight? {
        let withSleep = records.filter { $0.sleepHours > 0 }
        guard withSleep.count >= 6 else { return nil }

        let cal = Calendar.current
        var dayData = [Date: (count: Int, sleep: Double)]()
        for record in withSleep {
            let day = cal.startOfDay(for: record.completedAt)
            if let existing = dayData[day] {
                dayData[day] = (count: existing.count + 1, sleep: record.sleepHours)
            } else {
                dayData[day] = (count: 1, sleep: record.sleepHours)
            }
        }
        guard dayData.count >= 4 else { return nil }

        let goodDays = dayData.values.filter { $0.sleep >= 7.0 }
        let poorDays = dayData.values.filter { $0.sleep < 6.0 }
        guard goodDays.count >= 2, poorDays.count >= 2 else { return nil }

        let avgGood = Double(goodDays.map(\.count).reduce(0, +)) / Double(goodDays.count)
        let avgPoor = Double(poorDays.map(\.count).reduce(0, +)) / Double(poorDays.count)
        guard avgPoor > 0, avgGood > avgPoor + 0.5 else { return nil }

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

    static func consistencyInsight(from records: [ProductivityRecord]) -> Insight? {
        guard records.count >= minimumCompletions else { return nil }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sortedDays = Set(records.map { cal.startOfDay(for: $0.completedAt) }).sorted(by: >)

        var streak = 0
        var cursor = today
        for day in sortedDays {
            if cal.isDate(day, inSameDayAs: cursor) {
                streak += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
            } else if day < cursor {
                break
            }
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

        let onTimeRate = Int(Double(records.filter { $0.wasOnTime }.count) / Double(records.count) * 100)

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

        if records.count >= 10 && onTimeRate < 50 {
            let slipRate = 100 - onTimeRate
            return Insight(
                icon: "calendar.badge.clock",
                title: "Adjust Your Estimates",
                body: "About \(slipRate)% of tasks shift to a later day. Try scheduling a bit less — quality beats quantity.",
                highlight: "\(slipRate)% rescheduled",
                type: .consistency,
                chartBars: nil
            )
        }

        return nil
    }

    // MARK: - Evening Pattern

    static func eveningInsight(from records: [ProductivityRecord]) -> Insight? {
        guard records.count >= 8 else { return nil }

        let evening = records.filter { $0.completionHour >= 20 }
        let rate = Double(evening.count) / Double(records.count)
        guard rate > 0.20 else { return nil }

        let pct = Int(rate * 100)
        return Insight(
            icon: "moon.stars.fill",
            title: "Late-Night Pattern",
            body: "\(pct)% of your tasks get done after 8 PM. Try saving lighter tasks for evenings and protecting your earlier hours for focused work.",
            highlight: "\(pct)% after 8 PM",
            type: .energy,
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

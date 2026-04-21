import AppIntents
import SwiftData
import Foundation

struct TodayPlanIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Plan"
    static var description = IntentDescription("Get a spoken summary of your tasks for today.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try OrynSharedContainer.make()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<OrynTask>()
        let all = (try? context.fetch(descriptor)) ?? []

        let todayTasks = all.filter { task in
            guard !task.isCompleted, let scheduled = task.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }.sorted { $0.priorityRaw > $1.priorityRaw }

        guard !todayTasks.isEmpty else {
            return .result(dialog: "You have nothing scheduled for today. Enjoy the free time!")
        }

        let count = todayTasks.count
        let totalMinutes = todayTasks.reduce(0) { $0 + $1.durationMinutes }
        let timeString = formatDuration(totalMinutes)
        let completed = all.filter { $0.isCompleted && Calendar.current.isDateInToday($0.completedAt ?? .distantPast) }.count

        var parts: [String] = []

        if completed > 0 {
            parts.append("You've already completed \(completed) task\(completed > 1 ? "s" : "") today.")
        }

        parts.append("You have \(count) task\(count > 1 ? "s" : "") left, totaling \(timeString).")

        if let top = todayTasks.first(where: { $0.priority == .high }) {
            parts.append("Your top priority is \"\(top.title)\".")
        } else if let first = todayTasks.first {
            parts.append("Up next: \"\(first.title)\".")
        }

        return .result(dialog: .init(stringLiteral: parts.joined(separator: " ")))
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h) hour\(h > 1 ? "s" : "") and \(m) minutes" }
        if h > 0           { return "\(h) hour\(h > 1 ? "s" : "")" }
        return "\(m) minute\(m > 1 ? "s" : "")"
    }
}

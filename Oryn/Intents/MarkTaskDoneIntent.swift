import AppIntents
import SwiftData
import Foundation

struct MarkTaskDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Task as Done"
    static var description = IntentDescription("Complete a task by name.")

    @Parameter(title: "Task Name", description: "Which task did you finish?", requestValueDialog: "Which task did you complete?")
    var taskName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try OrynSharedContainer.make()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<OrynTask>()
        let all = (try? context.fetch(descriptor)) ?? []
        let incomplete = all.filter { !$0.isCompleted }

        guard let match = bestMatch(for: taskName, in: incomplete) else {
            return .result(dialog: "I couldn't find an incomplete task matching \"\(taskName)\". Check your task list in Oryn.")
        }

        match.isCompleted = true
        match.completedAt = Date()
        try? context.save()

        return .result(dialog: "Done! I've marked \"\(match.title)\" as complete.")
    }

    // Returns the task whose title best matches the query (case-insensitive contains, then word overlap).
    private func bestMatch(for query: String, in tasks: [OrynTask]) -> OrynTask? {
        let q = query.lowercased()

        // Exact or substring match first
        if let exact = tasks.first(where: { $0.title.lowercased() == q }) { return exact }
        if let sub   = tasks.first(where: { $0.title.lowercased().contains(q) }) { return sub }

        // Word overlap score
        let queryWords = Set(q.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        return tasks
            .map { task -> (OrynTask, Int) in
                let taskWords = Set(task.title.lowercased().components(separatedBy: .whitespaces))
                return (task, queryWords.intersection(taskWords).count)
            }
            .filter { $0.1 > 0 }
            .max(by: { $0.1 < $1.1 })?
            .0
    }
}

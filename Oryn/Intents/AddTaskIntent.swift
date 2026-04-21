import AppIntents
import SwiftData
import Foundation

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Add a new task to Oryn and schedule it automatically.")

    @Parameter(title: "Task", requestValueDialog: "What task would you like to add?")
    var taskTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try OrynSharedContainer.make()
        let context = ModelContext(container)

        let deadline = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        let task = OrynTask(
            title: taskTitle,
            deadline: deadline,
            durationMinutes: 30,
            priority: .medium,
            energyLevel: EnergyLevel.inferred(from: taskTitle)
        )
        context.insert(task)

        let descriptor = FetchDescriptor<OrynTask>()
        let all = (try? context.fetch(descriptor)) ?? []
        SchedulerEngine.redistribute(tasks: all, dailyCapMinutes: capFromDefaults())
        try? context.save()

        return .result(dialog: "Added \(taskTitle) to your tasks.")
    }

    private func capFromDefaults() -> Int {
        let hours = UserDefaults.standard.double(forKey: "dailyCapHours")
        return hours > 0 ? Int(hours * 60) : SchedulerEngine.defaultDailyCapMinutes
    }
}

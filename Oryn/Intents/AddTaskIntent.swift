import AppIntents
import SwiftData
import Foundation

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Add a new task to Oryn and schedule it automatically.")

    @Parameter(title: "Task", description: "What needs to be done?", requestValueDialog: "What task would you like to add?")
    var taskTitle: String

    @Parameter(title: "Priority", description: "How important is this task?", default: IntentPriority.medium)
    var priority: IntentPriority

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try OrynSharedContainer.make()
        let context = ModelContext(container)

        let deadline = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        let resolved = EnergyLevel.inferred(from: taskTitle)
        let task = OrynTask(
            title: taskTitle,
            deadline: deadline,
            durationMinutes: 30,
            priority: priority.asPriority,
            energyLevel: resolved
        )
        context.insert(task)

        let descriptor = FetchDescriptor<OrynTask>()
        let all = (try? context.fetch(descriptor)) ?? []
        let capMinutes = capFromDefaults()
        SchedulerEngine.redistribute(tasks: all, dailyCapMinutes: capMinutes)
        try? context.save()

        return .result(dialog: "Got it — I've added "\(taskTitle)" to your tasks.")
    }

    private func capFromDefaults() -> Int {
        let hours = UserDefaults.standard.double(forKey: "dailyCapHours")
        return hours > 0 ? Int(hours * 60) : SchedulerEngine.defaultDailyCapMinutes
    }
}

// MARK: - Priority bridge for App Intents

enum IntentPriority: String, AppEnum {
    case low, medium, high

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Priority"
    static var caseDisplayRepresentations: [IntentPriority: DisplayRepresentation] = [
        .low:    .init(title: "Low",    image: .init(systemName: "arrow.down.circle")),
        .medium: .init(title: "Medium", image: .init(systemName: "minus.circle")),
        .high:   .init(title: "High",   image: .init(systemName: "arrow.up.circle"))
    ]

    var asPriority: Priority {
        switch self {
        case .low:    return .low
        case .medium: return .medium
        case .high:   return .high
        }
    }
}

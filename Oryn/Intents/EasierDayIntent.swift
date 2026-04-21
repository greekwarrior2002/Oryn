import AppIntents
import SwiftData
import Foundation

struct EasierDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Give Me an Easier Day"
    static var description = IntentDescription("Push today's remaining tasks to tomorrow and lighten your schedule.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try OrynSharedContainer.make()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<OrynTask>()
        let all = (try? context.fetch(descriptor)) ?? []

        let todayIncomplete = all.filter { task in
            guard !task.isCompleted, let scheduled = task.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }

        guard !todayIncomplete.isEmpty else {
            return .result(dialog: "Your schedule is already clear for today. Nothing left to push!")
        }

        let count = todayIncomplete.count
        let capMinutes = capFromDefaults()
        SchedulerEngine.pushTodayForward(tasks: all, dailyCapMinutes: capMinutes)
        try? context.save()

        let word = count == 1 ? "task" : "tasks"
        return .result(dialog: "Done — I've moved \(count) \(word) to tomorrow. Enjoy the lighter day!")
    }

    private func capFromDefaults() -> Int {
        let hours = UserDefaults.standard.double(forKey: "dailyCapHours")
        return hours > 0 ? Int(hours * 60) : SchedulerEngine.defaultDailyCapMinutes
    }
}

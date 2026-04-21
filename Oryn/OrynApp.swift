import SwiftUI
import SwiftData

@main
struct OrynApp: App {
    let container: ModelContainer
    @StateObject private var taskStore: TaskStore

    init() {
        let schema = Schema([OrynTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let c = try ModelContainer(for: schema, configurations: [config])
            container = c
            // Read saved daily cap, default to 4 hours on first launch
            let savedHours = UserDefaults.standard.double(forKey: "dailyCapHours")
            let capMinutes = savedHours > 0 ? Int(savedHours * 60) : SchedulerEngine.defaultDailyCapMinutes
            _taskStore = StateObject(wrappedValue: TaskStore(context: c.mainContext, dailyCapMinutes: capMinutes))
        } catch {
            fatalError("SwiftData ModelContainer failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(taskStore)
                .modelContainer(container)
                .onAppear {
                    taskStore.rescheduleMissedTasks()
                }
        }
    }
}

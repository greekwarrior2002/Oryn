import SwiftUI
import SwiftData

@main
struct OrynApp: App {
    let container: ModelContainer
    @StateObject private var taskStore: TaskStore
    @StateObject private var healthKitManager = HealthKitManager()

    init() {
        let schema = Schema([OrynTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let c = try ModelContainer(
                for: schema,
                migrationPlan: OrynMigrationPlan.self,
                configurations: [config]
            )
            container = c
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
                .environmentObject(healthKitManager)
                .modelContainer(container)
                .onAppear {
                    taskStore.rescheduleMissedTasks()
                    Task {
                        await healthKitManager.requestAuthorization()
                        taskStore.applyAdaptiveSchedule(readiness: healthKitManager.readiness)
                    }
                }
        }
    }
}

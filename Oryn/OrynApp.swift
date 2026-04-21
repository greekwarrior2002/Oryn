import SwiftUI
import SwiftData
import AppIntents

@main
struct OrynApp: App {
    let container: ModelContainer
    @StateObject private var taskStore: TaskStore
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var insightsStore: InsightsStore

    init() {
        let schema = Schema([OrynTask.self, ProductivityRecord.self])
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
            _insightsStore = StateObject(wrappedValue: InsightsStore(context: c.mainContext))
        } catch {
            fatalError("SwiftData ModelContainer failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(taskStore)
                .environmentObject(healthKitManager)
                .environmentObject(insightsStore)
                .modelContainer(container)
                .onAppear {
                    taskStore.rescheduleMissedTasks()
                    OrynShortcuts.updateAppShortcutParameters()
                    Task {
                        await healthKitManager.requestAuthorization()
                        taskStore.applyAdaptiveSchedule(readiness: healthKitManager.readiness)
                    }
                }
        }
    }
}

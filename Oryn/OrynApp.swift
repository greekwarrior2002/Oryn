import SwiftUI
import SwiftData

@main
struct OrynApp: App {
    let container: ModelContainer
    @StateObject private var taskStore: TaskStore
    @AppStorage("dailyCapHours") private var dailyCapHours: Double = 4.0

    init() {
        let schema = Schema([Task.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let c = try ModelContainer(for: schema, configurations: [config])
            container = c
            _taskStore = StateObject(wrappedValue: TaskStore(
                context: c.mainContext,
                dailyCapMinutes: Int((UserDefaults.standard.double(forKey: "dailyCapHours").nonZero ?? 4.0) * 60)
            ))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
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

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

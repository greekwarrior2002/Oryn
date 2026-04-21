import AppIntents

struct OrynShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "New task in \(.applicationName)",
                "Create a task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: TodayPlanIntent(),
            phrases: [
                "What's my plan today in \(.applicationName)",
                "What do I have today in \(.applicationName)",
                "Show today's tasks in \(.applicationName)"
            ],
            shortTitle: "Today's Plan",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: MarkTaskDoneIntent(),
            phrases: [
                "Mark a task done in \(.applicationName)",
                "Complete a task in \(.applicationName)",
                "Finish a task in \(.applicationName)"
            ],
            shortTitle: "Mark Done",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: EasierDayIntent(),
            phrases: [
                "Give me an easier day in \(.applicationName)",
                "Too busy today in \(.applicationName)",
                "Lighten my schedule in \(.applicationName)"
            ],
            shortTitle: "Easier Day",
            systemImageName: "arrow.down.circle.fill"
        )
    }
}

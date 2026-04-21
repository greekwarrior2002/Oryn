import SwiftUI
import SwiftData

@MainActor
final class TaskStore: ObservableObject {

    private let context: ModelContext
    @Published var tasks: [Task] = []
    @Published var dailyCapMinutes: Int

    init(context: ModelContext, dailyCapMinutes: Int = SchedulerEngine.defaultDailyCapMinutes) {
        self.context = context
        self.dailyCapMinutes = dailyCapMinutes
        fetchTasks()
    }

    // MARK: - Computed Views

    var todayTasks: [Task] {
        let today = SchedulerEngine.startOfDay(Date())
        return tasks
            .filter { task in
                guard !task.isCompleted,
                      let date = task.scheduledDate else { return false }
                return Calendar.current.isDate(date, inSameDayAs: today)
            }
            .sorted { $0.priority.sortWeight > $1.priority.sortWeight }
    }

    var completedTodayTasks: [Task] {
        tasks.filter { task in
            guard task.isCompleted,
                  let completedAt = task.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }
    }

    var scheduledDays: [ScheduleDay] {
        let today = SchedulerEngine.startOfDay(Date())
        return (0..<14).compactMap { offset -> ScheduleDay? in
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: today) else { return nil }
            let dayTasks = tasks.filter {
                guard let scheduled = $0.scheduledDate else { return false }
                return Calendar.current.isDate(scheduled, inSameDayAs: day)
            }
            // Only show days that have tasks or are today
            guard !dayTasks.isEmpty || offset == 0 else { return nil }
            return ScheduleDay(date: day, tasks: dayTasks)
        }
    }

    var todayProgress: Double {
        let today = tasks.filter { task in
            guard let scheduled = task.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }
        let total = today.reduce(0) { $0 + $1.durationMinutes }
        let done = today.filter { $0.isCompleted }.reduce(0) { $0 + $1.durationMinutes }
        guard total > 0 else { return 0 }
        return min(Double(done) / Double(total), 1.0)
    }

    var todayCompletedMinutes: Int {
        completedTodayTasks.reduce(0) { $0 + $1.durationMinutes }
    }

    var todayTotalMinutes: Int {
        let today = tasks.filter { task in
            guard let scheduled = task.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }
        return today.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - CRUD

    func addTask(title: String, deadline: Date, durationMinutes: Int, priority: Priority) {
        let task = Task(title: title, deadline: deadline, durationMinutes: durationMinutes, priority: priority)
        context.insert(task)
        fetchTasks()
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    func completeTask(_ task: Task) {
        task.isCompleted = true
        task.completedAt = Date()
        save()
        objectWillChange.send()
    }

    func uncompleteTask(_ task: Task) {
        task.isCompleted = false
        task.completedAt = nil
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    func deleteTask(_ task: Task) {
        context.delete(task)
        fetchTasks()
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    // MARK: - Scheduling Actions

    func rescheduleMissedTasks() {
        SchedulerEngine.rescheduleMissed(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    func tooBusyToday() {
        SchedulerEngine.pushTodayForward(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    func doneEarly() {
        SchedulerEngine.pullForward(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    func updateDailyCap(_ minutes: Int) {
        dailyCapMinutes = minutes
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    // MARK: - Persistence

    func fetchTasks() {
        let descriptor = FetchDescriptor<Task>(sortBy: [SortDescriptor(\.createdAt)])
        tasks = (try? context.fetch(descriptor)) ?? []
    }

    private func save() {
        try? context.save()
    }
}

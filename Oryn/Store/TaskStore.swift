import SwiftUI
import SwiftData

@MainActor
final class TaskStore: ObservableObject {

    private let context: ModelContext
    @Published var tasks: [OrynTask] = []
    @Published var dailyCapMinutes: Int

    /// The most recently completed task, available for undo. Cleared after ~3.5 seconds.
    @Published var undoTask: OrynTask? = nil
    private var undoClearJob: Task<Void, Never>? = nil

    init(context: ModelContext, dailyCapMinutes: Int = SchedulerEngine.defaultDailyCapMinutes) {
        self.context = context
        self.dailyCapMinutes = dailyCapMinutes
        fetchTasks()
    }

    // MARK: - Computed Views

    var todayTasks: [OrynTask] {
        let today = SchedulerEngine.startOfDay(Date())
        return tasks
            .filter { task in
                guard !task.isCompleted,
                      !task.isInBacklog,
                      let date = task.scheduledDate else { return false }
                return Calendar.current.isDate(date, inSameDayAs: today)
            }
            .sorted { $0.priority.sortWeight > $1.priority.sortWeight }
    }

    var completedTodayTasks: [OrynTask] {
        tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }
    }

    var backlogTasks: [OrynTask] {
        tasks
            .filter { $0.isInBacklog && !$0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Next 14 days, only days that have tasks (plus today always included).
    /// Backlog tasks are excluded from the week view.
    var scheduledDays: [ScheduleDay] {
        let today = SchedulerEngine.startOfDay(Date())
        return (0..<14).compactMap { offset -> ScheduleDay? in
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: today) else { return nil }
            let dayTasks = tasks.filter {
                guard !$0.isInBacklog,
                      let scheduled = $0.scheduledDate else { return false }
                return Calendar.current.isDate(scheduled, inSameDayAs: day)
            }
            guard !dayTasks.isEmpty || offset == 0 else { return nil }
            return ScheduleDay(date: day, tasks: dayTasks)
        }
    }

    var todayProgress: Double {
        let todayAll = tasks.filter { task in
            guard !task.isInBacklog,
                  let scheduled = task.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }
        let total = todayAll.reduce(0) { $0 + $1.durationMinutes }
        let done  = todayAll.filter { $0.isCompleted }.reduce(0) { $0 + $1.durationMinutes }
        guard total > 0 else { return 0 }
        return min(Double(done) / Double(total), 1.0)
    }

    var todayCompletedMinutes: Int {
        completedTodayTasks.reduce(0) { $0 + $1.durationMinutes }
    }

    var todayTotalMinutes: Int {
        tasks.filter { task in
            guard !task.isInBacklog,
                  let scheduled = task.scheduledDate else { return false }
            return Calendar.current.isDateInToday(scheduled)
        }
        .reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - CRUD

    func addTask(
        title: String,
        deadline: Date,
        durationMinutes: Int,
        priority: Priority,
        energyLevel: EnergyLevel? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceCustomDays: [Int] = [],
        schedulePinnedDate: Date? = nil,
        scheduleNotBeforeDate: Date? = nil,
        isLocked: Bool = false
    ) {
        let resolved = energyLevel ?? EnergyLevel.inferred(from: title)
        let task = OrynTask(title: title, deadline: deadline, durationMinutes: durationMinutes,
                            priority: priority, energyLevel: resolved)
        task.recurrenceRule        = recurrenceRule
        task.recurrenceCustomDays  = recurrenceCustomDays
        task.schedulePinnedDate    = schedulePinnedDate
        task.scheduleNotBeforeDate = scheduleNotBeforeDate
        task.isLocked              = isLocked
        context.insert(task)
        tasks.append(task)
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func addBacklogTask(title: String) {
        let task = OrynTask(
            title: title,
            deadline: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
            durationMinutes: 30,
            priority: .medium,
            isBacklog: true
        )
        context.insert(task)
        tasks.append(task)
        save()
        fetchTasks()
    }

    /// Converts a backlog task into a fully scheduled task.
    func promoteFromBacklog(
        _ task: OrynTask,
        title: String,
        deadline: Date,
        durationMinutes: Int,
        priority: Priority,
        energyLevel: EnergyLevel
    ) {
        task.title           = title
        task.deadline        = deadline
        task.durationMinutes = durationMinutes
        task.priority        = priority
        task.energyLevel     = energyLevel
        task.isInBacklog     = false
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func completeTask(_ task: OrynTask) {
        task.isCompleted = true
        task.completedAt = Date()

        // Spawn next recurrence occurrence if applicable
        if let rule = task.recurrenceRule,
           let nextDate = rule.nextOccurrence(
               after: task.completedAt ?? Date(),
               customDays: task.recurrenceCustomDays
           ) {
            spawnRecurrence(from: task, nextDate: nextDate)
        }

        save()
        fetchTasks()
        scheduleUndoClear(for: task)
        refreshNotifications()
    }

    func uncompleteTask(_ task: OrynTask) {
        task.isCompleted = false
        task.completedAt = nil
        undoClearJob?.cancel()
        undoTask = nil
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func undoComplete() {
        guard let task = undoTask else { return }
        undoClearJob?.cancel()
        undoTask = nil
        uncompleteTask(task)
    }

    private func scheduleUndoClear(for task: OrynTask) {
        undoClearJob?.cancel()
        undoTask = task
        undoClearJob = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.orynSmooth) { self?.undoTask = nil }
        }
    }

    func updateTask(
        _ task: OrynTask,
        title: String,
        deadline: Date,
        durationMinutes: Int,
        priority: Priority,
        energyLevel: EnergyLevel,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceCustomDays: [Int] = [],
        schedulePinnedDate: Date? = nil,
        scheduleNotBeforeDate: Date? = nil,
        isLocked: Bool = false
    ) {
        task.title               = title
        task.deadline            = deadline
        task.durationMinutes     = durationMinutes
        task.priority            = priority
        task.energyLevel         = energyLevel
        task.recurrenceRule      = recurrenceRule
        task.recurrenceCustomDays  = recurrenceCustomDays
        task.schedulePinnedDate    = schedulePinnedDate
        task.scheduleNotBeforeDate = scheduleNotBeforeDate
        task.isLocked              = isLocked
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func deleteTask(_ task: OrynTask) {
        context.delete(task)
        tasks.removeAll { $0.id == task.id }
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func rescheduleTaskToTomorrow(_ task: OrynTask) {
        guard !task.isCompleted else { return }
        let tomorrow = SchedulerEngine.nextDay(SchedulerEngine.startOfDay(Date()))
        task.scheduledDate = tomorrow
        save()
        fetchTasks()
        refreshNotifications()
    }

    // MARK: - Manual Scheduling Controls

    func pinTask(_ task: OrynTask, to date: Date) {
        task.schedulePinnedDate = SchedulerEngine.startOfDay(date)
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func unpinTask(_ task: OrynTask) {
        task.schedulePinnedDate = nil
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    func setNotBeforeDate(_ task: OrynTask, date: Date?) {
        task.scheduleNotBeforeDate = date.map { SchedulerEngine.startOfDay($0) }
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
    }

    func setLocked(_ task: OrynTask, locked: Bool) {
        task.isLocked = locked
        if !locked {
            SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        }
        save()
        fetchTasks()
    }

    // MARK: - Scheduling Actions

    func rescheduleMissedTasks() {
        SchedulerEngine.rescheduleMissed(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func tooBusyToday() {
        SchedulerEngine.pushTodayForward(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func doneEarly() {
        SchedulerEngine.pullForward(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    func applyAdaptiveSchedule(readiness: ReadinessScore) {
        SchedulerEngine.adaptiveRedistribute(
            tasks: tasks,
            dailyCapMinutes: dailyCapMinutes,
            readiness: readiness
        )
        save()
        fetchTasks()
        refreshNotifications()
    }

    func updateDailyCap(_ minutes: Int) {
        dailyCapMinutes = minutes
        SchedulerEngine.redistribute(tasks: tasks, dailyCapMinutes: dailyCapMinutes)
        save()
        fetchTasks()
        refreshNotifications()
    }

    // MARK: - Persistence

    func fetchTasks() {
        let descriptor = FetchDescriptor<OrynTask>(sortBy: [SortDescriptor(\.createdAt)])
        tasks = (try? context.fetch(descriptor)) ?? []
    }

    private func save() {
        try? context.save()
    }

    // MARK: - Private: Recurrence Spawning

    private func spawnRecurrence(from original: OrynTask, nextDate: Date) {
        let next = OrynTask(
            title: original.title,
            deadline: nextDeadline(from: original, nextDate: nextDate),
            durationMinutes: original.durationMinutes,
            priority: original.priority,
            energyLevel: original.energyLevel
        )
        next.recurrenceRule        = original.recurrenceRule
        next.recurrenceCustomDays  = original.recurrenceCustomDays
        next.parentRecurrenceId    = original.parentRecurrenceId ?? original.id
        next.scheduleNotBeforeDate = nextDate
        context.insert(next)
        tasks.append(next)
    }

    private func nextDeadline(from task: OrynTask, nextDate: Date) -> Date {
        // Keep deadline offset from the scheduled date, or use the next occurrence date + buffer
        let originalOffset = Calendar.current.dateComponents(
            [.day],
            from: SchedulerEngine.startOfDay(task.scheduledDate ?? task.deadline),
            to: SchedulerEngine.startOfDay(task.deadline)
        ).day ?? 0
        return Calendar.current.date(byAdding: .day, value: max(0, originalOffset), to: nextDate)
            ?? Calendar.current.date(byAdding: .day, value: 7, to: nextDate)
            ?? nextDate
    }

    // MARK: - Private: Notifications

    private func refreshNotifications() {
        NotificationManager.shared.rescheduleNotifications(for: tasks)
    }
}

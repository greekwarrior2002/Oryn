import XCTest
import SwiftData
@testable import Oryn

// MARK: - Helpers

private extension SchedulerEngineTests {
    func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: OrynTask.self, configurations: config)
    }

    func makeTask(
        _ title: String,
        deadline daysFromNow: Int,
        duration: Int = 60,
        priority: Priority = .medium,
        context: ModelContext
    ) -> OrynTask {
        let deadline = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        let task = OrynTask(title: title, deadline: deadline, durationMinutes: duration, priority: priority)
        context.insert(task)
        return task
    }

    var today: Date { SchedulerEngine.startOfDay(Date()) }
    var tomorrow: Date { SchedulerEngine.nextDay(today) }
}

// MARK: - Tests

final class SchedulerEngineTests: XCTestCase {

    // MARK: redistribute — basic assignment

    func testRedistribute_assignsTaskToToday_whenCapacityAvailable() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let task = makeTask("Buy groceries", daysFromNow: 3, duration: 30, context: ctx)

        SchedulerEngine.redistribute(tasks: [task], dailyCapMinutes: 240)

        XCTAssertNotNil(task.scheduledDate)
        XCTAssertEqual(SchedulerEngine.startOfDay(task.scheduledDate!), today)
    }

    func testRedistribute_spillsToNextDay_whenTodayFull() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        // Fill today with 4 × 60-min tasks (= 240 min cap)
        let tasks = (0..<4).map { i in makeTask("Task \(i)", daysFromNow: 5, duration: 60, context: ctx) }
        let overflow = makeTask("Overflow", daysFromNow: 5, duration: 60, context: ctx)
        let all = tasks + [overflow]

        SchedulerEngine.redistribute(tasks: all, dailyCapMinutes: 240)

        let overflowDay = SchedulerEngine.startOfDay(overflow.scheduledDate!)
        XCTAssertEqual(overflowDay, tomorrow, "Overflow task should land on tomorrow")
    }

    func testRedistribute_respectsDeadline_pinsToDeadlineWhenNoRoom() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        // Deadline is today; fill today beyond cap
        let blocker = makeTask("Blocker", daysFromNow: 5, duration: 240, context: ctx)
        let urgent = makeTask("Urgent", daysFromNow: 0, duration: 60, context: ctx)

        SchedulerEngine.redistribute(tasks: [blocker, urgent], dailyCapMinutes: 240)

        let urgentDay = SchedulerEngine.startOfDay(urgent.scheduledDate!)
        XCTAssertEqual(urgentDay, today, "Task due today must stay today even if day is full")
    }

    // MARK: redistribute — completed task capacity accounting

    func testRedistribute_accountsForCompletedWork_reducingRemainingCapacity() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        // 200 minutes already completed today
        let done = makeTask("Done", daysFromNow: 0, duration: 200, context: ctx)
        done.isCompleted = true
        done.completedAt = Date()
        done.scheduledDate = today

        // New 60-min task: only 40 min remain under 240-min cap → should NOT fit today
        let newTask = makeTask("New", daysFromNow: 5, duration: 60, context: ctx)

        SchedulerEngine.redistribute(tasks: [done, newTask], dailyCapMinutes: 240)

        let assignedDay = SchedulerEngine.startOfDay(newTask.scheduledDate!)
        XCTAssertEqual(assignedDay, tomorrow,
            "New task should not fit today since 200m of completed work already consumed the cap")
    }

    // MARK: pushTodayForward

    func testPushTodayForward_movesTasksOffToday() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let task = makeTask("Meeting prep", daysFromNow: 5, duration: 60, context: ctx)
        task.scheduledDate = today

        SchedulerEngine.pushTodayForward(tasks: [task], dailyCapMinutes: 240)

        let day = SchedulerEngine.startOfDay(task.scheduledDate!)
        XCTAssertNotEqual(day, today, "Task should have moved off today after pushTodayForward")
    }

    func testPushTodayForward_doesNotMovePastDeadline() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        // Task is due today — can't move it to tomorrow
        let task = makeTask("Due today", daysFromNow: 0, duration: 60, context: ctx)
        task.scheduledDate = today

        SchedulerEngine.pushTodayForward(tasks: [task], dailyCapMinutes: 240)

        let day = SchedulerEngine.startOfDay(task.scheduledDate!)
        XCTAssertEqual(day, today, "Task due today must remain on today even after pushTodayForward")
    }

    func testPushTodayForward_doesNotRelandOnToday() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        // Large cap so the task would normally land today in a plain redistribute
        let task = makeTask("Pushed task", daysFromNow: 7, duration: 30, context: ctx)
        task.scheduledDate = today

        SchedulerEngine.pushTodayForward(tasks: [task], dailyCapMinutes: 480)

        let day = SchedulerEngine.startOfDay(task.scheduledDate!)
        XCTAssertEqual(day, tomorrow,
            "pushTodayForward must start redistribution from tomorrow so tasks don't land back on today")
    }

    // MARK: Priority ordering

    func testRedistribute_highPriorityScheduledBeforeLow_whenSameDeadline() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let low  = makeTask("Low prio",  daysFromNow: 3, duration: 120, priority: .low,  context: ctx)
        let high = makeTask("High prio", daysFromNow: 3, duration: 120, priority: .high, context: ctx)

        // Cap is exactly 120 min so only one fits per day
        SchedulerEngine.redistribute(tasks: [low, high], dailyCapMinutes: 120)

        let highDay = SchedulerEngine.startOfDay(high.scheduledDate!)
        let lowDay  = SchedulerEngine.startOfDay(low.scheduledDate!)
        XCTAssertEqual(highDay, today,    "High priority task should land first (today)")
        XCTAssertEqual(lowDay,  tomorrow, "Low priority task should land second (tomorrow)")
    }
}

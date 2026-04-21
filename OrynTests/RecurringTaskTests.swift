import XCTest
import SwiftData
@testable import Oryn

final class RecurringTaskTests: XCTestCase {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: OrynTask.self, configurations: config)
    }

    private func makeTask(
        _ title: String,
        deadline daysFromNow: Int = 7,
        duration: Int = 30,
        context: ModelContext
    ) -> OrynTask {
        let deadline = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        let task = OrynTask(title: title, deadline: deadline, durationMinutes: duration, priority: .medium)
        context.insert(task)
        return task
    }

    private var today: Date { SchedulerEngine.startOfDay(Date()) }
    private var tomorrow: Date { SchedulerEngine.nextDay(today) }
    private var cal: Calendar { Calendar.current }

    // MARK: - RecurrenceRule.nextOccurrence

    func testDaily_nextOccurrence_isOneDayLater() {
        let base = Date()
        let next = RecurrenceRule.daily.nextOccurrence(after: base)
        XCTAssertNotNil(next)
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: base), to: cal.startOfDay(for: next!)).day
        XCTAssertEqual(diff, 1, "Daily recurrence should produce next occurrence exactly 1 day later")
    }

    func testWeekly_nextOccurrence_isSevenDaysLater() {
        let base = Date()
        let next = RecurrenceRule.weekly.nextOccurrence(after: base)
        XCTAssertNotNil(next)
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: base), to: cal.startOfDay(for: next!)).day
        XCTAssertEqual(diff, 7, "Weekly recurrence should produce next occurrence 7 days later")
    }

    func testWeekdays_skipsWeekend() {
        // Pick a Friday
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: Date())
        comps.weekday = 6  // Friday
        let friday = cal.date(from: comps) ?? Date()

        let next = RecurrenceRule.weekdays.nextOccurrence(after: friday)
        XCTAssertNotNil(next)
        let wd = cal.component(.weekday, from: next!)
        // Should be Monday (weekday 2), skipping Saturday and Sunday
        XCTAssertEqual(wd, 2, "Weekdays recurrence after Friday should land on Monday")
    }

    func testMonthly_nextOccurrence_isOneMonthLater() {
        let base = Date()
        let next = RecurrenceRule.monthly.nextOccurrence(after: base)
        XCTAssertNotNil(next)
        let diff = cal.dateComponents([.month], from: base, to: next!).month
        XCTAssertEqual(diff, 1, "Monthly recurrence should produce next occurrence 1 month later")
    }

    func testCustom_nextOccurrence_landsOnCorrectWeekday() {
        // Custom: only Wednesdays (weekday 4)
        let base = Date()
        let next = RecurrenceRule.custom.nextOccurrence(after: base, customDays: [4])
        XCTAssertNotNil(next)
        let wd = cal.component(.weekday, from: next!)
        XCTAssertEqual(wd, 4, "Custom recurrence with only Wednesday should land on Wednesday")
    }

    func testCustom_emptyDays_returnsNil() {
        let next = RecurrenceRule.custom.nextOccurrence(after: Date(), customDays: [])
        XCTAssertNil(next, "Custom recurrence with no days selected should return nil")
    }

    // MARK: - Backlog skipped by scheduler

    func testRedistribute_skipsBacklogTasks() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let backlog = makeTask("Backlog task", context: ctx)
        backlog.isInBacklog = true

        let regular = makeTask("Regular task", context: ctx)

        SchedulerEngine.redistribute(tasks: [backlog, regular], dailyCapMinutes: 240)

        XCTAssertNil(backlog.scheduledDate, "Backlog task should not receive a scheduledDate")
        XCTAssertNotNil(regular.scheduledDate, "Regular task should receive a scheduledDate")
    }

    // MARK: - Locked tasks preserved

    func testRedistribute_preservesLockedTaskDate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let locked = makeTask("Locked task", context: ctx)
        locked.isLocked = true
        locked.scheduledDate = tomorrow

        let other = makeTask("Other task", context: ctx)

        SchedulerEngine.redistribute(tasks: [locked, other], dailyCapMinutes: 240)

        XCTAssertEqual(
            SchedulerEngine.startOfDay(locked.scheduledDate!),
            tomorrow,
            "Locked task should keep its scheduledDate after redistribution"
        )
    }

    // MARK: - Pinned date constraint

    func testRedistribute_respectsPinnedDate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let pinTarget = cal.date(byAdding: .day, value: 3, to: today)!
        let task = makeTask("Pinned task", context: ctx)
        task.schedulePinnedDate = pinTarget

        SchedulerEngine.redistribute(tasks: [task], dailyCapMinutes: 240)

        XCTAssertEqual(
            SchedulerEngine.startOfDay(task.scheduledDate!),
            SchedulerEngine.startOfDay(pinTarget),
            "Pinned task should be scheduled on the pinned date"
        )
    }

    // MARK: - notBeforeDate constraint

    func testRedistribute_respectsNotBeforeDate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let notBefore = cal.date(byAdding: .day, value: 2, to: today)!
        let task = makeTask("NotBefore task", context: ctx)
        task.scheduleNotBeforeDate = notBefore

        SchedulerEngine.redistribute(tasks: [task], dailyCapMinutes: 240)

        XCTAssertNotNil(task.scheduledDate)
        XCTAssertGreaterThanOrEqual(
            SchedulerEngine.startOfDay(task.scheduledDate!),
            SchedulerEngine.startOfDay(notBefore),
            "Task should not be scheduled before notBeforeDate"
        )
    }

    // MARK: - Recurrence label

    func testRecurrenceLabel_dailyRule() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let task = makeTask("Daily", context: ctx)
        task.recurrenceRule = .daily

        XCTAssertEqual(task.recurrenceLabel, "Daily")
    }

    func testRecurrenceLabel_customDays() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let task = makeTask("Custom", context: ctx)
        task.recurrenceRule        = .custom
        task.recurrenceCustomDays  = [2, 4]  // Mon, Wed

        // Labels come from Calendar.veryShortWeekdaySymbols, order may vary by locale.
        let label = task.recurrenceLabel ?? ""
        XCTAssertFalse(label.isEmpty, "Custom recurrence label should not be empty")
    }

    // MARK: - rescheduleMissed skips backlog and locked

    func testRescheduleMissed_doesNotTouchBacklog() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let backlog = makeTask("Backlog", context: ctx)
        backlog.isInBacklog    = true
        backlog.scheduledDate  = cal.date(byAdding: .day, value: -3, to: today)   // past date

        SchedulerEngine.rescheduleMissed(tasks: [backlog], dailyCapMinutes: 240)

        // scheduledDate should remain unchanged since backlog tasks are skipped
        XCTAssertNotNil(backlog.scheduledDate, "Backlog task should not be touched by rescheduleMissed")
    }
}

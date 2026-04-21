import Foundation

struct ScheduleDay: Identifiable {
    let date: Date
    var tasks: [OrynTask]

    var id: String {
        date.formatted(.dateTime.year().month().day())
    }

    var totalScheduledMinutes: Int {
        tasks.filter { !$0.isCompleted }.reduce(0) { $0 + $1.durationMinutes }
    }

    var completedMinutes: Int {
        tasks.filter { $0.isCompleted }.reduce(0) { $0 + $1.durationMinutes }
    }

    var progressFraction: Double {
        let total = totalScheduledMinutes + completedMinutes
        guard total > 0 else { return 0 }
        return min(Double(completedMinutes) / Double(total), 1.0)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isFull: Bool {
        totalScheduledMinutes >= SchedulerEngine.defaultDailyCapMinutes
    }

    var formattedDate: String {
        date.formatted(.dateTime.weekday(.wide).month().day())
    }

    var shortDayName: String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    var dayNumber: String {
        date.formatted(.dateTime.day())
    }
}

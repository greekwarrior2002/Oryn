import SwiftUI

/// The redesigned "This Week" tab.
///
/// Instead of just showing a daily-progress bar for each day (passive), the new
/// design is organised around what the user *needs to act on*:
///
///   1. A **summary pill row** — overdue count, due this week, overload flags.
///   2. **Overdue carry-forward** if any — scheduler already puts these on
///      today, but the list makes the damage explicit.
///   3. **Top priorities** for the week — the 3 highest-priority active tasks.
///   4. **Days** — 7 consecutive days from today, each with its actual task
///      list + capacity bar. Tapping a day scrolls/expands it.
///   5. Subtle weather awareness at the top.
///
/// Heavy logic lives in `WeeklyPlannerService` so the view stays declarative.
struct WeekView: View {
    @EnvironmentObject var store: TaskStore
    @StateObject private var weather = WeatherService.shared
    @Binding var showAddTask: Bool

    // Recomputing the plan on every state change is cheap (7-day window, pure
    // filters) and keeps the view declarative without ObservableObject glue.
    private var plan: WeekPlan {
        WeeklyPlannerService.plan(
            tasks: store.tasks,
            dailyCapMinutes: store.dailyCapMinutes
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.md)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    summaryRow

                    if plan.summary.tasksThisWeek == 0 && plan.overdueTasks.isEmpty {
                        WeekEmptyState(showAddTask: $showAddTask)
                            .padding(.top, Spacing.xl)
                    } else {
                        if !plan.overdueTasks.isEmpty {
                            WeekOverdueSection(tasks: plan.overdueTasks)
                        }

                        if !plan.priorities.isEmpty {
                            WeekPrioritiesSection(tasks: plan.priorities)
                        }

                        daysSection
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orynBackground.ignoresSafeArea())
        .task { await weather.refreshIfNeeded() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("SCHEDULE")
                    .orynFont(.orynCaption, color: .orynTextSecondary)
                    .tracking(1.5)
                Text("This Week")
                    .orynFont(.orynLargeTitle)
                Text(rangeLabel)
                    .orynFont(.orynCaption, color: .orynTextTertiary)
            }
            Spacer()
            if let snap = weather.snapshot {
                HStack(spacing: 4) {
                    Image(systemName: snap.symbol)
                        .font(.system(size: 12))
                    Text(snap.temperatureDisplay)
                        .orynFont(.orynCaption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orynSurface))
                .accessibilityLabel("Current weather: \(snap.headline)")
            }
        }
    }

    private var rangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: plan.weekStart)) – \(f.string(from: plan.weekEnd))"
    }

    // MARK: - Summary row

    private var summaryRow: some View {
        let s = plan.summary
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                WeekSummaryPill(
                    icon: "exclamationmark.circle.fill",
                    value: "\(s.overdueCount)",
                    label: "Overdue",
                    tint: s.hasOverdue ? .red : .orynTextTertiary
                )
                WeekSummaryPill(
                    icon: "calendar",
                    value: "\(s.dueThisWeek)",
                    label: "Due",
                    tint: .orynAccent
                )
                WeekSummaryPill(
                    icon: "checkmark.circle.fill",
                    value: "\(s.completedThisWeek)",
                    label: "Done",
                    tint: .orynSuccess
                )
                if s.hasOverloaded {
                    WeekSummaryPill(
                        icon: "flame.fill",
                        value: "\(s.overloadedDays.count)",
                        label: "Heavy",
                        tint: .orange
                    )
                }
                if s.hasFreeDays {
                    WeekSummaryPill(
                        icon: "leaf.fill",
                        value: "\(s.freeDays.count)",
                        label: "Free",
                        tint: .orynSuccess
                    )
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Days section

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("DAYS")
            VStack(spacing: Spacing.sm) {
                ForEach(plan.days) { day in
                    WeekPlanDayRow(day: day)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .orynFont(.orynCaption, color: .orynTextSecondary)
            .tracking(1.5)
            .padding(.top, Spacing.sm)
    }
}

// MARK: - Summary pill

private struct WeekSummaryPill: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tint)
            Text(value)
                .orynFont(.orynSubheadline)
                .fontWeight(.semibold)
            Text(label)
                .orynFont(.orynCaption, color: .orynTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.pill)
                .fill(Color.orynSurface)
        )
    }
}

// MARK: - Overdue section

private struct WeekOverdueSection: View {
    @EnvironmentObject var store: TaskStore
    let tasks: [OrynTask]
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                HapticManager.shared.light()
                withAnimation(.orynSpring) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("Overdue")
                        .orynFont(.orynHeadline)
                    Text("\(tasks.count)")
                        .orynFont(.orynCaption, color: .white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.orynTextTertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: Spacing.xs) {
                    ForEach(tasks) { task in
                        OverdueTaskRow(task: task)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orange.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(Color.orange.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

private struct OverdueTaskRow: View {
    @EnvironmentObject var store: TaskStore
    let task: OrynTask

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .orynFont(.orynSubheadline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(overdueLabel)
                        .orynFont(.orynCaption, color: .orange)
                    Text("·")
                        .orynFont(.orynCaption, color: .orynTextTertiary)
                    Text(task.durationLabel)
                        .orynFont(.orynCaption, color: .orynTextTertiary)
                }
            }
            Spacer()
            Menu {
                Button {
                    HapticManager.shared.light()
                    store.scheduleInboxTask(task, on: Date())
                } label: {
                    Label("Do today", systemImage: "sun.max")
                }
                Button {
                    HapticManager.shared.light()
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    store.scheduleInboxTask(task, on: tomorrow)
                } label: {
                    Label("Do tomorrow", systemImage: "arrow.forward.circle")
                }
                Divider()
                Button(role: .destructive) {
                    store.deleteTask(task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var overdueLabel: String {
        guard let scheduled = task.scheduledDate else { return "Overdue" }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: scheduled),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        if days <= 1 { return "1 day overdue" }
        return "\(days) days overdue"
    }
}

// MARK: - Priorities section

private struct WeekPrioritiesSection: View {
    let tasks: [OrynTask]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("THIS WEEK'S FOCUS")
                .orynFont(.orynCaption, color: .orynTextSecondary)
                .tracking(1.5)
                .padding(.top, Spacing.sm)
            VStack(spacing: Spacing.sm) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                    PriorityRow(rank: idx + 1, task: task)
                }
            }
        }
    }
}

private struct PriorityRow: View {
    let rank: Int
    let task: OrynTask

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Text("\(rank)")
                .orynFont(.orynTitle2, color: .orynAccent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .orynFont(.orynSubheadline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(task.priority.color).frame(width: 6, height: 6)
                    Text(task.priority.label)
                        .orynFont(.orynCaption, color: .orynTextTertiary)
                    Text("·")
                        .orynFont(.orynCaption, color: .orynTextTertiary)
                    Text(dayLabel)
                        .orynFont(.orynCaption, color: .orynTextTertiary)
                    Text("·")
                        .orynFont(.orynCaption, color: .orynTextTertiary)
                    Text(task.durationLabel)
                        .orynFont(.orynCaption, color: .orynTextTertiary)
                }
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynSurface)
        )
    }

    private var dayLabel: String {
        let date = task.scheduledDate ?? task.deadline
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Per-day row

private struct WeekPlanDayRow: View {
    let day: WeekPlanDay
    @State private var isExpanded: Bool

    init(day: WeekPlanDay) {
        self.day = day
        // Default: today + tomorrow expanded; other days collapsed to keep the
        // screen scannable. Users can tap to expand.
        let cal = Calendar.current
        let openByDefault = cal.isDateInToday(day.date) || cal.isDateInTomorrow(day.date)
        _isExpanded = State(initialValue: openByDefault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.shared.light()
                withAnimation(.orynSpring) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: Spacing.md) {
                    dayBadge
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weekdayName)
                            .orynFont(.orynHeadline, color: day.isToday ? .orynAccent : .orynTextPrimary)
                        Text(day.loadSummary)
                            .orynFont(.orynCaption, color: .orynTextTertiary)
                    }
                    Spacer()
                    loadBar
                        .frame(width: 80, height: 5)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.orynTextTertiary)
                        .frame(width: 14)
                }
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynSurface)
        )
    }

    // MARK: - Subviews

    private var dayBadge: some View {
        VStack(spacing: 0) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(day.isToday ? .orynAccent : .orynTextTertiary)
            Text(day.date.formatted(.dateTime.day()))
                .font(.system(size: 17, weight: day.isToday ? .bold : .medium))
                .foregroundColor(day.isToday ? .orynTextPrimary : .orynTextSecondary)
        }
        .frame(width: 36, height: 40)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(day.isToday ? Color.orynAccent.opacity(0.12) : Color.clear)
        )
    }

    private var loadBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.orynSurfaceSecondary)
                Capsule()
                    .fill(barGradient)
                    .frame(width: max(0, geo.size.width * day.loadFraction))
            }
        }
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: day.loadFraction >= 1.0
                ? [Color.orange, Color.red.opacity(0.8)]
                : [Color.orynAccent, Color.orynSuccess],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var weekdayName: String {
        let cal = Calendar.current
        if cal.isDateInToday(day.date) { return "Today" }
        if cal.isDateInTomorrow(day.date) { return "Tomorrow" }
        return day.date.formatted(.dateTime.weekday(.wide))
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if day.scheduled.isEmpty && day.completed.isEmpty {
                Text("No tasks scheduled")
                    .orynFont(.orynCaption, color: .orynTextTertiary)
                    .padding(.vertical, Spacing.xs)
            } else {
                ForEach(day.scheduled) { task in
                    WeekTaskLine(task: task, isCompleted: false)
                }
                ForEach(day.completed) { task in
                    WeekTaskLine(task: task, isCompleted: true)
                }
            }
        }
        .padding(.leading, 36 + Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}

// MARK: - Task line (compact day-list row)

private struct WeekTaskLine: View {
    let task: OrynTask
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(isCompleted ? .orynSuccess : task.priority.color.opacity(0.8))
            Text(task.title)
                .orynFont(.orynCaption, color: isCompleted ? .orynTextTertiary : .orynTextPrimary)
                .strikethrough(isCompleted, color: .orynTextTertiary)
                .lineLimit(1)
            Spacer()
            if let timeLabel = task.dueTimeLabel {
                Text(timeLabel)
                    .orynFont(.orynCaption, color: .orynTextTertiary)
            } else {
                Text(task.durationLabel)
                    .orynFont(.orynCaption, color: .orynTextTertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Empty state

private struct WeekEmptyState: View {
    @Binding var showAddTask: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(LinearGradient(
                    colors: [.orynAccent, .orynSuccess],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: Spacing.sm) {
                Text("A calm week")
                    .orynFont(.orynTitle2)
                Text("Nothing scheduled — add tasks with deadlines and Oryn will plan them across the week.")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            OrynButton("Add a task", style: .primary, icon: "plus") {
                HapticManager.shared.light()
                showAddTask = true
            }
        }
        .frame(maxWidth: .infinity)
    }
}

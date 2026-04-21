import SwiftUI

struct WeekDaySection: View {
    let day: ScheduleDay
    @EnvironmentObject var store: TaskStore
    @State private var isExpanded = true

    private let dailyCapMinutes = 240.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            Button {
                HapticManager.shared.light()
                withAnimation(.orynSpring) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: Spacing.md) {
                    // Date label
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.shortDayName.uppercased())
                            .orynFont(.orynCaption, color: day.isToday ? .orynAccent : .orynTextTertiary)
                            .tracking(1.5)

                        Text(day.isToday ? "Today" : day.dayNumber)
                            .font(.system(size: 26, weight: day.isToday ? .bold : .regular))
                            .foregroundColor(day.isToday ? .orynTextPrimary : .orynTextSecondary)
                    }
                    .frame(width: 52, alignment: .leading)

                    // Load bar
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.orynSurface)
                                    .frame(height: 5)
                                Capsule()
                                    .fill(loadBarGradient)
                                    .frame(
                                        width: max(0, geo.size.width * loadFraction),
                                        height: 5
                                    )
                                    .animation(.orynRing, value: loadFraction)
                            }
                        }
                        .frame(height: 5)

                        Text(loadLabel)
                            .orynFont(.orynCaption, color: .orynTextTertiary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orynTextTertiary)
                }
                .padding(.vertical, Spacing.md)
            }
            .buttonStyle(.plain)

            // Task rows (collapsible)
            if isExpanded {
                VStack(spacing: Spacing.xs) {
                    if day.tasks.isEmpty {
                        Text("Nothing scheduled")
                            .orynFont(.orynCaption, color: .orynTextTertiary)
                            .padding(.bottom, Spacing.md)
                            .padding(.leading, 52 + Spacing.md)
                    } else {
                        ForEach(day.tasks) { task in
                            WeekTaskRow(task: task)
                        }
                        .padding(.bottom, Spacing.sm)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()
                .padding(.leading, 52 + Spacing.md)
        }
    }

    private var loadFraction: CGFloat {
        min(CGFloat(day.totalScheduledMinutes + day.completedMinutes) / dailyCapMinutes, 1.0)
    }

    private var loadLabel: String {
        let total = day.totalScheduledMinutes + day.completedMinutes
        if total == 0 { return "Free" }
        let h = total / 60
        let m = total % 60
        let timeStr = h > 0 ? (m > 0 ? "\(h)h \(m)m" : "\(h)h") : "\(m)m"
        return day.isFull ? "\(timeStr) · Full" : timeStr
    }

    private var loadBarGradient: LinearGradient {
        let isFull = loadFraction >= 1.0
        return LinearGradient(
            colors: isFull ? [.red.opacity(0.8), .red] : [.orynAccent, .orynSuccess],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Week Task Row

struct WeekTaskRow: View {
    let task: Task

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Priority color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(task.isCompleted ? Color.orynTextTertiary : task.priority.color)
                .frame(width: 3, height: 28)
                .opacity(task.isCompleted ? 0.4 : 1.0)

            Text(task.title)
                .orynFont(.orynSubheadline,
                          color: task.isCompleted ? .orynTextTertiary : .orynTextPrimary)
                .strikethrough(task.isCompleted, color: .orynTextTertiary)
                .lineLimit(1)

            Spacer()

            Text(task.durationLabel)
                .orynFont(.orynCaption, color: .orynTextTertiary)
        }
        .padding(.leading, 52 + Spacing.md)
        .padding(.trailing, Spacing.md)
        .padding(.vertical, 4)
    }
}

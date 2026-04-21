import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var healthKit: HealthKitManager
    @Binding var showAddTask: Bool
    @Binding var showScanner: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                    .padding(.top, Spacing.xl)

                ReadinessCardView()

                if store.todayTotalMinutes > 0 {
                    DayProgressView(
                        progress: store.todayProgress,
                        completedMinutes: store.todayCompletedMinutes,
                        totalMinutes: store.todayTotalMinutes
                    )
                }

                if store.todayTasks.isEmpty && store.completedTodayTasks.isEmpty {
                    EmptyTodayView(showAddTask: $showAddTask)
                } else {
                    taskSection
                }

                if !store.todayTasks.isEmpty {
                    contextualActions
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, 120) // clearance for custom tab bar
        }
        .background(Color.orynBackground.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .orynFont(.orynCaption, color: .orynTextSecondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text("Today")
                    .orynFont(.orynLargeTitle)
            }
            Spacer()
            HStack(spacing: Spacing.sm) {
                Button {
                    HapticManager.shared.light()
                    showScanner = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.orynSurface)
                            .frame(width: 40, height: 40)
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orynAccent)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.shared.light()
                    showAddTask = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.orynAccent)
                            .frame(width: 40, height: 40)
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Task List

    private var taskSection: some View {
        VStack(spacing: Spacing.sm) {
            // Use id-based animation on the container, not transition on each card.
            // This avoids conflict with the card's own scale/opacity completion animation.
            ForEach(store.todayTasks) { task in
                TaskCardView(task: task)
            }
            .animation(.orynSpring, value: store.todayTasks.map(\.id))

            if !store.completedTodayTasks.isEmpty {
                CompletedSection(tasks: store.completedTodayTasks)
            }
        }
    }

    // MARK: - Contextual Actions

    private var contextualActions: some View {
        HStack {
            Button {
                HapticManager.shared.medium()
                SoundManager.shared.playReschedule()
                withAnimation(.orynSmooth) { store.tooBusyToday() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.forward.circle")
                        .font(.system(size: 13))
                    Text("Too busy today")
                        .orynFont(.orynButtonSm, color: .orynTextSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                HapticManager.shared.light()
                withAnimation(.orynSmooth) { store.doneEarly() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                    Text("Done early")
                        .orynFont(.orynButtonSm, color: .orynTextSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Completed Section

private struct CompletedSection: View {
    let tasks: [OrynTask]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                HapticManager.shared.light()
                withAnimation(.orynSpring) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("\(tasks.count) completed")
                        .orynFont(.orynCaption, color: .orynTextTertiary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.orynTextTertiary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)

            if isExpanded {
                ForEach(tasks) { task in
                    TaskCardView(task: task)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

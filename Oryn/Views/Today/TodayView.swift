import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: TaskStore
    @Binding var showAddTask: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                    .padding(.top, Spacing.xl)

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
            .padding(.bottom, 120)
        }
        .background(Color.orynBackground.ignoresSafeArea())
        .animation(.orynSmooth, value: store.todayTasks.map(\.id))
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

            // Add button
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

    // MARK: - Task List

    private var taskSection: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(store.todayTasks) { task in
                TaskCardView(task: task)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.92).combined(with: .opacity)
                    ))
            }

            // Completed tasks (collapsed at bottom, dimmed)
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
    let tasks: [Task]
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

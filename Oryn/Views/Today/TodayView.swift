import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var healthKit: HealthKitManager
    @Binding var showAddTask: Bool
    @Binding var showScanner: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Pinned header — never scrolls away, unaffected by list animations
                header
                    .padding(.top, Spacing.xl)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.lg) {
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
                    .padding(.bottom, 120)
                }
            }
            .background(Color.orynBackground.ignoresSafeArea())

            // Undo toast — floats above tab bar after a task is completed
            if let task = store.undoTask {
                UndoToast(message: "Completed "\(task.title)"") {
                    HapticManager.shared.medium()
                    store.undoComplete()
                }
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.orynSpring, value: store.undoTask?.id)
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
                .accessibilityLabel("Scan tasks")
                .accessibilityHint("Import tasks from a photo or camera")

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
                .accessibilityLabel("Add task")
                .accessibilityHint("Opens the new task form")
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
            .accessibilityLabel("Too busy today")
            .accessibilityHint("Moves all remaining tasks to tomorrow or later")

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
            .accessibilityLabel("Done early")
            .accessibilityHint("Pulls upcoming tasks forward to fill today's remaining capacity")
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

// MARK: - Undo Toast

struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(message)
                .orynFont(.orynCaption, color: .white)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button("Undo", action: onUndo)
                .orynFont(.orynCaption, color: .orynAccent)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.82))
        )
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAction(named: "Undo", onUndo)
    }
}

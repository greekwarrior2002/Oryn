import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var healthKit: HealthKitManager
    @Binding var showAddTask: Bool
    @Binding var showScanner: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
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

                        // A compact hint pointing to the Inbox tab when there
                        // are unscheduled captures. The full inbox lives on its
                        // own tab — we don't duplicate it here.
                        if !store.inboxTasks.isEmpty {
                            InboxHintRow(count: store.inboxTasks.count)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, 120)
                }
            }
            .background(Color.orynBackground.ignoresSafeArea())

            if let task = store.undoTask {
                UndoToast(message: "Completed \"\(task.title)\"") {
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
                        Circle().fill(Color.orynSurface).frame(width: 40, height: 40)
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orynAccent)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan tasks")

                Button {
                    HapticManager.shared.light()
                    showAddTask = true
                } label: {
                    ZStack {
                        Circle().fill(Color.orynAccent).frame(width: 40, height: 40)
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add task")
            }
        }
    }

    // MARK: - Task List

    private var taskSection: some View {
        VStack(spacing: Spacing.sm) {
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
                    Image(systemName: "arrow.forward.circle").font(.system(size: 13))
                    Text("Too busy today").orynFont(.orynButtonSm, color: .orynTextSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                HapticManager.shared.light()
                withAnimation(.orynSmooth) { store.doneEarly() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "bolt.fill").font(.system(size: 12))
                    Text("Done early").orynFont(.orynButtonSm, color: .orynTextSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Backlog Section

struct BacklogSectionView: View {
    @EnvironmentObject var store: TaskStore
    @State private var isExpanded = false
    @State private var showPromoteSheet: OrynTask? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                HapticManager.shared.light()
                withAnimation(.orynSpring) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orynAccent)
                    Text("Inbox")
                        .orynFont(.orynHeadline)
                    Text("\(store.backlogTasks.count)")
                        .orynFont(.orynCaption, color: .white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orynAccent))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.orynTextTertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: Spacing.xs) {
                    ForEach(store.backlogTasks) { task in
                        BacklogTaskRow(task: task, onPlan: { showPromoteSheet = task })
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
        .sheet(item: $showPromoteSheet) { task in
            PromoteBacklogView(task: task)
                .environmentObject(store)
        }
    }
}

// MARK: - Backlog Task Row

private struct BacklogTaskRow: View {
    @EnvironmentObject var store: TaskStore
    let task: OrynTask
    let onPlan: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(task.title)
                .orynFont(.orynSubheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                HapticManager.shared.light()
                onPlan()
            } label: {
                Text("Plan")
                    .orynFont(.orynCaption, color: .orynAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .strokeBorder(Color.orynAccent, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Spacing.xs)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.deleteTask(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Promote Backlog Sheet

struct PromoteBacklogView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) var dismiss
    let task: OrynTask

    @State private var title: String
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var durationMinutes = 30
    @State private var priority: Priority = .medium
    @State private var energyLevel: EnergyLevel = .medium

    init(task: OrynTask) {
        self.task = task
        _title = State(initialValue: task.title)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Task name", text: $title, axis: .vertical)
                            .orynFont(.orynTitle2)
                            .lineLimit(1...3)
                        Text("Set the details to move this to your schedule.")
                            .orynFont(.orynCaption, color: .orynTextSecondary)
                    }
                    .padding(.top, Spacing.xs)

                    Divider()

                    RowLabel(title: "Deadline", icon: "calendar") {
                        DatePicker("", selection: $deadline, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                            .accentColor(.orynAccent)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Duration")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                        DurationPickerView(selected: $durationMinutes)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Priority")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                        PriorityPickerView(selected: $priority)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Energy needed")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                        EnergyPickerView(selected: $energyLevel)
                    }

                    Spacer(minLength: Spacing.xl)

                    Button {
                        HapticManager.shared.success()
                        store.promoteFromBacklog(
                            task,
                            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? task.title : title,
                            deadline: deadline,
                            durationMinutes: durationMinutes,
                            priority: priority,
                            energyLevel: energyLevel
                        )
                        dismiss()
                    } label: {
                        Text("Schedule Task")
                            .orynFont(.orynButton, color: .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.orynAccent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.orynBackground.ignoresSafeArea())
            .navigationTitle("Plan Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.orynTextSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

// MARK: - Inbox hint (lightweight pointer to the Inbox tab)

private struct InboxHintRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "tray.fill")
                .foregroundColor(.orynAccent)
                .font(.system(size: 14))
            Text("\(count) in Inbox")
                .orynFont(.orynSubheadline)
            Spacer()
            Text("Plan later")
                .orynFont(.orynCaption, color: .orynTextTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynAccent.opacity(0.08))
        )
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
        .background(Capsule().fill(Color.black.opacity(0.82)))
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAction(named: "Undo", onUndo)
    }
}

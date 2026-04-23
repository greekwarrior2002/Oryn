import SwiftUI

/// Dedicated Inbox screen — the calm capture zone for unscheduled tasks.
///
/// Tasks arrive here either:
///   • directly from Quick Add when no date keyword was detected, or
///   • manually via "Move to Inbox" from another view.
///
/// Swipe actions let the user schedule an inbox task to Today/Tomorrow or
/// delete it. Tapping a card opens the detailed editor.
struct InboxView: View {
    @EnvironmentObject var store: TaskStore
    @Binding var showAddTask: Bool
    @State private var promoteTask: OrynTask? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xl)

                if store.inboxTasks.isEmpty {
                    InboxEmptyState(showAddTask: $showAddTask)
                        .padding(.top, Spacing.xxl)
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(store.inboxTasks) { task in
                            InboxTaskRow(
                                task: task,
                                onSchedule: { promoteTask = task }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .animation(.orynSpring, value: store.inboxTasks.map(\.id))
                }
            }
            .padding(.bottom, 120)
        }
        .background(Color.orynBackground.ignoresSafeArea())
        .sheet(item: $promoteTask) { task in
            PromoteBacklogView(task: task)
                .environmentObject(store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("CAPTURE")
                .orynFont(.orynCaption, color: .orynTextSecondary)
                .tracking(1.5)
            HStack(alignment: .firstTextBaseline) {
                Text("Inbox")
                    .orynFont(.orynLargeTitle)
                if !store.inboxTasks.isEmpty {
                    Text("\(store.inboxTasks.count)")
                        .orynFont(.orynTitle2, color: .orynTextTertiary)
                }
                Spacer()
            }
            Text("Quick captures. No pressure — plan them when you're ready.")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
        }
    }
}

// MARK: - Inbox task row

struct InboxTaskRow: View {
    @EnvironmentObject var store: TaskStore
    let task: OrynTask
    let onSchedule: () -> Void

    @State private var showEdit = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Button {
                HapticManager.shared.success()
                SoundManager.shared.playCompletion()
                store.completeTask(task)
            } label: {
                AnimatedCheckmark(isChecked: task.isCompleted)
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.shared.light()
                showEdit = true
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(task.title)
                        .orynFont(.orynHeadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: Spacing.xs) {
                        if task.source != .manual {
                            Label(task.source.label, systemImage: task.source.icon)
                                .orynFont(.orynCaption, color: .orynTextTertiary)
                                .labelStyle(.titleAndIcon)
                        }
                        if task.inferredFromTitle {
                            Text("auto")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orynAccent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.orynAccent.opacity(0.12)))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.shared.medium()
                onSchedule()
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orynAccent)
                    .padding(Spacing.sm)
                    .background(Circle().fill(Color.orynAccent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Schedule \(task.title)")
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
        .swipeActions(
            onLeading: {
                HapticManager.shared.success()
                SoundManager.shared.playCompletion()
                store.completeTask(task)
            },
            onTrailing: {
                HapticManager.shared.medium()
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                store.scheduleInboxTask(task, on: tomorrow)
            }
        )
        .contextMenu {
            Button {
                onSchedule()
            } label: {
                Label("Schedule…", systemImage: "calendar.badge.plus")
            }
            Button {
                let today = Date()
                store.scheduleInboxTask(task, on: today)
            } label: {
                Label("Do today", systemImage: "sun.max")
            }
            Button {
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
        }
        .sheet(isPresented: $showEdit) {
            EditTaskView(task: task)
                .environmentObject(store)
        }
    }
}

// MARK: - Empty state

private struct InboxEmptyState: View {
    @Binding var showAddTask: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 54, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orynAccent, .teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: Spacing.sm) {
                Text("Inbox is empty")
                    .orynFont(.orynTitle2)
                Text("Capture anything — Oryn will help you plan it later.")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            OrynButton("Capture a thought", style: .primary, icon: "plus") {
                HapticManager.shared.light()
                showAddTask = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.md)
    }
}

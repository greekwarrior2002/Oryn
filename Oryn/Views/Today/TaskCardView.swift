import SwiftUI

struct TaskCardView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var insightsStore: InsightsStore
    @EnvironmentObject var healthKit: HealthKitManager
    let task: OrynTask

    @State private var isCompleting = false
    @State private var showEdit = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            // Completion button
            Button {
                if task.isCompleted {
                    HapticManager.shared.light()
                    store.uncompleteTask(task)
                } else {
                    triggerCompletion()
                }
            } label: {
                AnimatedCheckmark(isChecked: task.isCompleted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted
                ? "Mark \(task.title) incomplete"
                : "Complete \(task.title)")
            .accessibilityHint(task.isCompleted ? "Removes completion" : "Marks task done")

            // Task info — tapping opens edit sheet
            Button {
                guard !task.isCompleted else { return }
                HapticManager.shared.light()
                showEdit = true
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(task.title)
                        .orynFont(.orynHeadline)
                        .strikethrough(task.isCompleted, color: .orynTextTertiary)
                        .foregroundColor(task.isCompleted ? .orynTextTertiary : .orynTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: Spacing.sm) {
                        Label(task.durationLabel, systemImage: "clock")
                            .orynFont(.orynCaption, color: .orynTextSecondary)
                            .labelStyle(CompactLabelStyle())

                        if task.deadlineIsToday && !task.isCompleted {
                            DeadlineBadge(isOverdue: false)
                        } else if task.isOverdue && !task.isCompleted {
                            DeadlineBadge(isOverdue: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? task.title : "Edit \(task.title)")
            .accessibilityHint(task.isCompleted ? "" : "Opens task editor")

            Circle()
                .fill(task.priority.color)
                .frame(width: 8, height: 8)
                .opacity(task.isCompleted ? 0.3 : 1.0)
                .accessibilityLabel("\(task.priority.label) priority")
                .accessibilityHidden(task.isCompleted)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
        .scaleEffect(isCompleting ? 0.93 : 1.0)
        .opacity(isCompleting ? 0 : 1.0)
        .animation(.orynBounce, value: isCompleting)
        .swipeActions(
            onLeading: {
                guard !task.isCompleted else { return }
                triggerCompletion()
            },
            onTrailing: {
                guard !task.isCompleted else { return }
                HapticManager.shared.medium()
                SoundManager.shared.playReschedule()
                store.rescheduleTaskToTomorrow(task)
            }
        )
        .contextMenu {
            if !task.isCompleted {
                Button {
                    HapticManager.shared.light()
                    showEdit = true
                } label: {
                    Label("Edit Task", systemImage: "pencil")
                }

                Button {
                    triggerCompletion()
                } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle")
                }

                Button {
                    HapticManager.shared.medium()
                    SoundManager.shared.playReschedule()
                    store.rescheduleTaskToTomorrow(task)
                } label: {
                    Label("Move to Tomorrow", systemImage: "arrow.forward.circle")
                }
            }

            Divider()

            Button(role: .destructive) {
                HapticManager.shared.medium()
                store.deleteTask(task)
            } label: {
                Label("Delete Task", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showEdit) {
            EditTaskView(task: task)
                .environmentObject(store)
        }
    }

    private func triggerCompletion() {
        guard !task.isCompleted else { return }
        HapticManager.shared.success()
        SoundManager.shared.playCompletion()
        withAnimation(.orynBounce) { isCompleting = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            store.completeTask(task)
            insightsStore.recordCompletion(task: task, readiness: healthKit.readiness)
        }
    }
}

// MARK: - Sub-components

private struct DeadlineBadge: View {
    let isOverdue: Bool
    var body: some View {
        Text(isOverdue ? "Overdue" : "Due today")
            .orynFont(.orynCaption, color: isOverdue ? .red : .orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill((isOverdue ? Color.red : Color.orange).opacity(0.12)))
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

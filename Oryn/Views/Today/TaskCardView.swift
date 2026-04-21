import SwiftUI

struct TaskCardView: View {
    @EnvironmentObject var store: TaskStore
    let task: Task

    @State private var isCompleting = false

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

            // Task info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(task.title)
                    .orynFont(.orynHeadline)
                    .strikethrough(task.isCompleted, color: .orynTextTertiary)
                    .foregroundColor(task.isCompleted ? .orynTextTertiary : .orynTextPrimary)
                    .lineLimit(2)

                HStack(spacing: Spacing.sm) {
                    // Duration
                    Label(task.durationLabel, systemImage: "clock")
                        .orynFont(.orynCaption, color: .orynTextSecondary)
                        .labelStyle(CompactLabelStyle())

                    // Deadline badge (if due today or overdue)
                    if task.deadlineIsToday && !task.isCompleted {
                        DeadlineBadge(isOverdue: false)
                    } else if task.isOverdue && !task.isCompleted {
                        DeadlineBadge(isOverdue: true)
                    }
                }
            }

            Spacer()

            // Priority dot
            Circle()
                .fill(task.priority.color)
                .frame(width: 8, height: 8)
                .opacity(task.isCompleted ? 0.3 : 1.0)
        }
        .padding(Spacing.md)
        .background(cardBackground)
        .scaleEffect(isCompleting ? 0.93 : 1.0)
        .opacity(isCompleting ? 0 : 1.0)
        .animation(.orynBounce, value: isCompleting)
        .swipeActions(
            onLeading: {
                guard !task.isCompleted else { return }
                triggerCompletion()
            },
            onTrailing: {
                HapticManager.shared.medium()
                SoundManager.shared.playReschedule()
                store.tooBusyToday()
            }
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Radius.md)
            .fill(Color.orynSurface)
            .orynCardShadow()
    }

    private func triggerCompletion() {
        guard !task.isCompleted else { return }
        HapticManager.shared.success()
        SoundManager.shared.playCompletion()
        withAnimation(.orynBounce) { isCompleting = true }
        // Delay model update so the shrink-out animation can play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            store.completeTask(task)
            isCompleting = false
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
            .background(
                Capsule().fill((isOverdue ? Color.red : Color.orange).opacity(0.12))
            )
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

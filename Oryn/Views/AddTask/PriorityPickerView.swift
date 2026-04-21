import SwiftUI

struct PriorityPickerView: View {
    @Binding var selected: Priority

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Priority.allCases) { priority in
                PriorityChip(priority: priority, isSelected: selected == priority) {
                    HapticManager.shared.light()
                    withAnimation(.orynSpring) { selected = priority }
                }
            }
        }
    }
}

struct PriorityChip: View {
    let priority: Priority
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: priority.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(priority.label)
                    .orynFont(.orynButtonSm)
            }
            .foregroundColor(isSelected ? priority.color : .orynTextSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? priority.color.opacity(0.12) : Color.orynSurface)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? priority.color.opacity(0.4) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(.orynSpring, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

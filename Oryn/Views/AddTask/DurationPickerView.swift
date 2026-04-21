import SwiftUI

struct DurationPickerView: View {
    @Binding var selected: Int
    let options = [15, 30, 60, 120]

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(options, id: \.self) { minutes in
                DurationChip(minutes: minutes, isSelected: selected == minutes) {
                    HapticManager.shared.light()
                    withAnimation(.orynSpring) { selected = minutes }
                }
            }
        }
    }
}

struct DurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var label: String {
        minutes >= 60 ? "\(minutes / 60)h" : "\(minutes)m"
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .orynFont(.orynButtonSm, color: isSelected ? .white : .orynTextSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule().fill(isSelected ? Color.orynAccent : Color.orynSurface)
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .animation(.orynSpring, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

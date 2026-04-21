import SwiftUI

struct EnergyPickerView: View {
    @Binding var selected: EnergyLevel

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(EnergyLevel.allCases) { level in
                EnergyChip(level: level, isSelected: selected == level) {
                    HapticManager.shared.light()
                    withAnimation(.orynSpring) { selected = level }
                }
            }
        }
    }
}

struct EnergyChip: View {
    let level: EnergyLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: level.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(level.label)
                    .orynFont(.orynButtonSm)
            }
            .foregroundColor(isSelected ? level.color : .orynTextSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? level.color.opacity(0.12) : Color.orynSurface)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? level.color.opacity(0.4) : Color.clear,
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

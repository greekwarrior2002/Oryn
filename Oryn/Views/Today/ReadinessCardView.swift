import SwiftUI

struct ReadinessCardView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @State private var isExpanded = false

    var body: some View {
        if healthKit.authorizationStatus == .unavailable {
            EmptyView()
        } else {
            Button {
                HapticManager.shared.light()
                withAnimation(.orynSpring) { isExpanded.toggle() }
            } label: {
                if isExpanded {
                    expandedCard(healthKit.readiness)
                } else {
                    collapsedPill(healthKit.readiness)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Collapsed

    private func collapsedPill(_ readiness: ReadinessScore) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(levelColor(readiness.level))
                .frame(width: 8, height: 8)
            Text("Readiness · \(readiness.level.label)")
                .orynFont(.orynCaption, color: .orynTextSecondary)
            Image(systemName: "chevron.down")
                .font(.system(size: 10))
                .foregroundColor(.orynTextTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Capsule().fill(levelColor(readiness.level).opacity(0.10)))
    }

    // MARK: - Expanded

    private func expandedCard(_ readiness: ReadinessScore) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(levelColor(readiness.level))
                        .frame(width: 10, height: 10)
                    Text("Readiness Score")
                        .orynFont(.orynHeadline)
                }
                Spacer()
                Text("\(readiness.value)")
                    .orynFont(.orynTitle2, color: levelColor(readiness.level))
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundColor(.orynTextTertiary)
            }

            Text(readiness.insight)
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: Spacing.lg) {
                statView(
                    icon: "moon.fill",
                    value: readiness.sleepHours > 0
                        ? String(format: "%.1fh", readiness.sleepHours)
                        : "—",
                    label: "Sleep"
                )
                statView(
                    icon: "figure.walk",
                    value: readiness.stepCount > 0
                        ? readiness.stepCount.formatted()
                        : "—",
                    label: "Steps"
                )
                Spacer()
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(levelColor(readiness.level).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(levelColor(readiness.level).opacity(0.2), lineWidth: 1)
                )
        )
        .orynCardShadow()
    }

    private func statView(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.orynTextTertiary)
                Text(value)
                    .orynFont(.orynHeadline)
            }
            Text(label)
                .orynFont(.orynCaption, color: .orynTextSecondary)
        }
    }

    private func levelColor(_ level: ReadinessScore.Level) -> Color {
        switch level {
        case .low:    return .orynReschedule
        case .medium: return .orynAccent
        case .high:   return .orynSuccess
        }
    }
}

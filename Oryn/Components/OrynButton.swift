import SwiftUI

enum OrynButtonStyle {
    case primary    // filled accent background
    case secondary  // outline
    case ghost      // text only, subtle
}

struct OrynButton: View {
    let title: String
    var style: OrynButtonStyle = .primary
    var icon: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(title)
                    .orynFont(.orynButton, color: foregroundColor)
            }
            .padding(.horizontal, horizontalPad)
            .padding(.vertical, verticalPad)
            .background(backgroundShape)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.orynSpring, value: isPressed)
        }
        .buttonStyle(TrackingButtonStyle(isPressed: $isPressed))
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return isDestructive ? .red : .orynAccent
        case .ghost:     return isDestructive ? .red : .orynTextSecondary
        }
    }

    private var horizontalPad: CGFloat {
        switch style {
        case .primary, .secondary: return Spacing.lg
        case .ghost: return Spacing.sm
        }
    }

    private var verticalPad: CGFloat {
        switch style {
        case .primary, .secondary: return Spacing.sm + 2
        case .ghost: return Spacing.xs
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch style {
        case .primary:
            Capsule().fill(isDestructive ? Color.red : Color.orynAccent)
        case .secondary:
            Capsule()
                .strokeBorder(isDestructive ? Color.red : Color.orynAccent, lineWidth: 1.5)
        case .ghost:
            Color.clear
        }
    }
}

// Tracks pressed state without blocking the button action
private struct TrackingButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}

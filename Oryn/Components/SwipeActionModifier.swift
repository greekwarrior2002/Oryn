import SwiftUI

// Reusable horizontal swipe gesture modifier.
// Right swipe = leading action (complete), Left swipe = trailing action (reschedule).
struct SwipeActionModifier: ViewModifier {
    let threshold: CGFloat
    let leadingColor: Color
    let trailingColor: Color
    let leadingIcon: String
    let trailingIcon: String
    let onLeading: () -> Void
    let onTrailing: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var hasTriggered = false

    func body(content: Content) -> some View {
        ZStack {
            // Leading background (right swipe → complete)
            HStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(leadingColor)
                    .overlay(
                        Image(systemName: leadingIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(offsetX > 0 ? min(Double(offsetX / threshold), 1.0) : 0)
                            .scaleEffect(offsetX > threshold ? 1.1 : 1.0)
                            .animation(.orynSpring, value: offsetX > threshold),
                        alignment: .leading
                    )
                    .padding(.trailing, max(0, UIScreen.main.bounds.width - offsetX))
                    .opacity(offsetX > 0 ? 1 : 0)
                Spacer()
            }

            // Trailing background (left swipe → reschedule)
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(trailingColor)
                    .overlay(
                        Image(systemName: trailingIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(offsetX < 0 ? min(Double(-offsetX / threshold), 1.0) : 0)
                            .scaleEffect(offsetX < -threshold ? 1.1 : 1.0)
                            .animation(.orynSpring, value: offsetX < -threshold),
                        alignment: .trailing
                    )
                    .padding(.leading, max(0, UIScreen.main.bounds.width + offsetX))
                    .opacity(offsetX < 0 ? 1 : 0)
            }

            // Card content
            content
                .offset(x: offsetX)
                .gesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .onChanged { value in
                            let w = value.translation.width
                            let h = value.translation.height
                            // Only activate horizontal swipe if it's more horizontal than vertical
                            guard abs(w) > abs(h) else { return }
                            offsetX = w * 0.75 // slight damping

                            // Trigger haptic snap once per swipe
                            if !hasTriggered && abs(offsetX) > threshold {
                                hasTriggered = true
                                HapticManager.shared.selectionChanged()
                            }
                        }
                        .onEnded { value in
                            hasTriggered = false
                            if offsetX > threshold {
                                withAnimation(.orynSpring) { offsetX = 0 }
                                onLeading()
                            } else if offsetX < -threshold {
                                withAnimation(.orynSpring) { offsetX = 0 }
                                onTrailing()
                            } else {
                                withAnimation(.orynSpring) { offsetX = 0 }
                            }
                        }
                )
        }
    }
}

extension View {
    func swipeActions(
        threshold: CGFloat = 80,
        leadingColor: Color = .orynSuccess,
        trailingColor: Color = .orynReschedule,
        leadingIcon: String = "checkmark",
        trailingIcon: String = "calendar.badge.clock",
        onLeading: @escaping () -> Void,
        onTrailing: @escaping () -> Void
    ) -> some View {
        modifier(SwipeActionModifier(
            threshold: threshold,
            leadingColor: leadingColor,
            trailingColor: trailingColor,
            leadingIcon: leadingIcon,
            trailingIcon: trailingIcon,
            onLeading: onLeading,
            onTrailing: onTrailing
        ))
    }
}

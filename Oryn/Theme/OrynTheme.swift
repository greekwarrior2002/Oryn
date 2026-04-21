import SwiftUI

// MARK: - Color System
// Add these named colors to Assets.xcassets:
//   OrynBackground:       Light #FFFFFF    Dark #0F0F10
//   OrynSurface:          Light #F5F5F7    Dark #1C1C1E
//   OrynSurfaceSecondary: Light #EBEBED    Dark #2C2C2E
//   AccentColor:          Light #5E5CE6    Dark #7D7AFF

extension Color {
    static let orynBackground        = Color("OrynBackground")
    static let orynSurface           = Color("OrynSurface")
    static let orynSurfaceSecondary  = Color("OrynSurfaceSecondary")
    static let orynAccent            = Color("AccentColor")
    static let orynAccentSoft        = Color("AccentColor").opacity(0.12)
    static let orynSuccess           = Color(red: 0.196, green: 0.843, blue: 0.294)  // #32D74B
    static let orynSuccessSoft       = Color(red: 0.196, green: 0.843, blue: 0.294).opacity(0.14)
    static let orynReschedule        = Color.orange
    static let orynRescheduleSoft    = Color.orange.opacity(0.14)
    static let orynTextPrimary       = Color.primary
    static let orynTextSecondary     = Color.secondary
    static let orynTextTertiary      = Color(.tertiaryLabel)
}

// MARK: - Spacing
enum Spacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
enum Radius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 14
    static let lg:   CGFloat = 20
    static let xl:   CGFloat = 28
    static let pill: CGFloat = 100
}

// MARK: - Animations
extension Animation {
    // Snappy spring for card interactions and chip selection
    static let orynSpring   = Animation.spring(response: 0.35, dampingFraction: 0.72)
    // Smooth for layout transitions
    static let orynSmooth   = Animation.easeInOut(duration: 0.28)
    // Slower arc for progress ring
    static let orynRing     = Animation.easeOut(duration: 0.6)
    // Bouncy spring for the completion scale
    static let orynBounce   = Animation.spring(response: 0.4, dampingFraction: 0.6)
}

// MARK: - Card Shadow
struct CardShadow: ViewModifier {
    @Environment(\.colorScheme) var scheme
    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(scheme == .dark ? 0.28 : 0.07),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

extension View {
    func orynCardShadow() -> some View {
        modifier(CardShadow())
    }
}

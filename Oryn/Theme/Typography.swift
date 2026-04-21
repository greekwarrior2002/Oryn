import SwiftUI

// MARK: - Type Scale (San Francisco / Dynamic Type aware)
extension Font {
    static let orynLargeTitle  = Font.system(size: 34, weight: .bold)
    static let orynTitle       = Font.system(size: 22, weight: .semibold)
    static let orynTitle2      = Font.system(size: 18, weight: .semibold)
    static let orynHeadline    = Font.system(size: 16, weight: .medium)
    static let orynSubheadline = Font.system(size: 14, weight: .regular)
    static let orynCaption     = Font.system(size: 12, weight: .regular)
    static let orynButton      = Font.system(size: 15, weight: .semibold)
    static let orynButtonSm    = Font.system(size: 13, weight: .medium)
}

// MARK: - Convenience Modifier
struct OrynTextStyle: ViewModifier {
    let font: Font
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

extension View {
    func orynFont(_ font: Font, color: Color = .orynTextPrimary) -> some View {
        modifier(OrynTextStyle(font: font, color: color))
    }
}

import SwiftUI

struct EmptyTodayView: View {
    @Binding var showAddTask: Bool
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0

    private let titles = [
        "Clear for today.",
        "A clean slate.",
        "Ready to focus."
    ]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xxl)

            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orynAccent, .orynSuccess],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            VStack(spacing: Spacing.sm) {
                Text(titles.randomElement() ?? titles[0])
                    .orynFont(.orynTitle2)

                Text("Add a task and Oryn will organize your day.")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            OrynButton("Add your first task", style: .primary, icon: "plus") {
                HapticManager.shared.light()
                showAddTask = true
            }
            .padding(.top, Spacing.xs)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.orynBounce.delay(0.1)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }
}

import SwiftUI

/// Shown on first launch. Lets the user set their daily capacity before entering the app.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("dailyCapHours") private var dailyCapHours: Double = 4.0
    @State private var iconScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo / Brand
            VStack(spacing: Spacing.md) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orynAccent, .orynSuccess],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconScale)

                VStack(spacing: Spacing.xs) {
                    Text("Oryn")
                        .orynFont(.orynLargeTitle)

                    Text("Calm, automatic scheduling.")
                        .orynFont(.orynSubheadline, color: .orynTextSecondary)
                }
            }

            Spacer()

            // Daily cap setting
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("How many hours can you work each day?")
                    .orynFont(.orynTitle2)

                Text("Oryn will schedule your tasks to fit within this limit. You can change this anytime in Settings.")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Slider(value: $dailyCapHours, in: 1...10, step: 0.5)
                        .accentColor(.orynAccent)
                    Text(capLabel)
                        .orynFont(.orynHeadline, color: .orynAccent)
                        .frame(width: 70, alignment: .trailing)
                        .animation(.orynSpring, value: dailyCapHours)
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.orynSurface)
            )
            .padding(.horizontal, Spacing.md)

            Spacer(minLength: Spacing.xl)

            // CTA
            Button {
                HapticManager.shared.success()
                withAnimation(.orynSpring) {
                    isPresented = false
                }
            } label: {
                Text("Get started")
                    .orynFont(.orynButton, color: .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(Color.orynAccent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.md)

            Spacer(minLength: Spacing.xl)
        }
        .background(Color.orynBackground.ignoresSafeArea())
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.orynBounce.delay(0.1)) { iconScale = 1.0 }
            withAnimation(.orynSmooth.delay(0.2)) { contentOpacity = 1.0 }
        }
    }

    private var capLabel: String {
        let h = Int(dailyCapHours)
        let m = Int((dailyCapHours - Double(h)) * 60)
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

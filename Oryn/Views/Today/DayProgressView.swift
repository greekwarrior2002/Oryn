import SwiftUI

struct DayProgressView: View {
    let progress: Double         // 0.0 – 1.0
    let completedMinutes: Int
    let totalMinutes: Int

    @State private var animatedProgress: Double = 0

    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Arc ring
            ZStack {
                // Track
                Circle()
                    .strokeBorder(Color.orynAccentSoft, lineWidth: 7)
                    .frame(width: 68, height: 68)

                // Progress arc
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.orynAccent, .orynSuccess],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 68, height: 68)
                    .rotationEffect(.degrees(-90))

                // Center label
                Text(progress >= 1 ? "✓" : "\(Int(progress * 100))%")
                    .orynFont(.orynCaption, color: progress >= 1 ? .orynSuccess : .orynTextSecondary)
            }

            // Text summary
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(statusLabel)
                    .orynFont(.orynTitle2)

                if totalMinutes > 0 {
                    Text(detailLabel)
                        .orynFont(.orynCaption, color: .orynTextSecondary)
                }
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynAccentSoft)
        )
        .onAppear {
            withAnimation(.orynRing.delay(0.1)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.orynRing) {
                animatedProgress = new
            }
        }
    }

    private var statusLabel: String {
        if progress >= 1.0 { return "All done!" }
        if progress == 0 && totalMinutes == 0 { return "No tasks today" }
        if progress == 0 { return "Ready to focus" }
        return "Good progress"
    }

    private var detailLabel: String {
        let done = formatMinutes(completedMinutes)
        let left = formatMinutes(max(0, totalMinutes - completedMinutes))
        if progress >= 1.0 { return "\(done) completed" }
        return "\(done) done · \(left) left"
    }

    private func formatMinutes(_ m: Int) -> String {
        if m == 0 { return "0m" }
        let h = m / 60
        let min = m % 60
        if h == 0 { return "\(min)m" }
        if min == 0 { return "\(h)h" }
        return "\(h)h \(min)m"
    }
}

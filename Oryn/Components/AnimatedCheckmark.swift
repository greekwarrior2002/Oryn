import SwiftUI

struct AnimatedCheckmark: View {
    var isChecked: Bool
    var size: CGFloat = 26
    var color: Color = .orynSuccess

    @State private var drawProgress: CGFloat = 0
    @State private var fillScale: CGFloat = 0

    var body: some View {
        ZStack {
            // Fill circle (scales in on check)
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
                .scaleEffect(fillScale)

            // Stroke ring
            Circle()
                .strokeBorder(
                    isChecked ? color : Color.orynTextTertiary,
                    lineWidth: 2
                )
                .frame(width: size, height: size)
                .animation(.orynSpring, value: isChecked)

            // Drawn checkmark path
            if isChecked {
                CheckmarkPath()
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: size * 0.44, height: size * 0.34)
                    .offset(y: 1)
            }
        }
        .onChange(of: isChecked) { _, checked in
            if checked {
                drawProgress = 0
                fillScale = 0
                withAnimation(.easeOut(duration: 0.22)) { drawProgress = 1 }
                withAnimation(.orynBounce) { fillScale = 1 }
            } else {
                withAnimation(.orynSpring) {
                    drawProgress = 0
                    fillScale = 0
                }
            }
        }
        .onAppear {
            if isChecked {
                drawProgress = 1
                fillScale = 1
            }
        }
    }
}

private struct CheckmarkPath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY * 0.9))
        p.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        return p
    }
}

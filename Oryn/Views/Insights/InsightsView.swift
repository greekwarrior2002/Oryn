import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var insightsStore: InsightsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                    .padding(.top, Spacing.xl)

                statsRow

                content
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, 120)
        }
        .background(Color.orynBackground.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Insights")
                .orynFont(.orynLargeTitle)
            Text("Your productivity patterns")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Spacing.sm) {
            InsightStatPill(value: "\(insightsStore.totalCompletions)", label: "Tasks done")
            InsightStatPill(value: "\(insightsStore.daysTracked)", label: "Days tracked")
        }
    }

    // MARK: - Content routing

    @ViewBuilder
    private var content: some View {
        if insightsStore.hasEnoughData {
            if insightsStore.isGeneratingAI {
                aiLoadingCard
            } else if !insightsStore.insights.isEmpty {
                insightCards
                if let err = insightsStore.aiError {
                    aiErrorNote(err)
                }
            } else {
                // Has enough records but no patterns surfaced yet — analysing
                analyzingCard
            }
        } else {
            emptyState
        }
    }

    // MARK: - Insight Cards

    private var insightCards: some View {
        VStack(spacing: Spacing.md) {
            ForEach(insightsStore.insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    // MARK: - AI Loading

    private var aiLoadingCard: some View {
        HStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.orynAccent)
            Text("Analysing your patterns…")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
    }

    private func aiErrorNote(_ message: String) -> some View {
        Text("Note: \(message)")
            .orynFont(.orynCaption, color: .orynTextTertiary)
            .padding(.horizontal, Spacing.xs)
    }

    // MARK: - Analysing state (enough data, no insights fired yet)

    private var analyzingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.orynAccent)
                Spacer()
                Text("\(insightsStore.totalCompletions) tasks logged")
                    .orynFont(.orynCaption, color: .orynTextSecondary)
            }

            Text("Patterns forming")
                .orynFont(.orynTitle2)

            Text("You have enough data, but distinct patterns haven't emerged yet. Complete tasks at different times of day or across multiple days to surface insights.")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
    }

    // MARK: - Empty State (< minimumCompletions)

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            progressCard
            previewCard
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.orynAccent)
                Spacer()
                Text("\(insightsStore.totalCompletions) / \(InsightsEngine.minimumCompletions)")
                    .orynFont(.orynCaption, color: .orynTextSecondary)
            }

            Text("Your insights are forming")
                .orynFont(.orynTitle2)

            Group {
                if insightsStore.completionsNeeded > 0 {
                    let n = insightsStore.completionsNeeded
                    Text("Complete \(n) more task\(n == 1 ? "" : "s") to unlock personalized productivity patterns.")
                } else {
                    Text("Keep completing tasks — your patterns are emerging.")
                }
            }
            .orynFont(.orynSubheadline, color: .orynTextSecondary)
            .fixedSize(horizontal: false, vertical: true)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orynAccent.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orynAccent)
                        .frame(width: geo.size.width * insightsStore.progressToFirstInsight, height: 6)
                        .animation(.orynSmooth, value: insightsStore.progressToFirstInsight)
                }
            }
            .frame(height: 6)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("What you'll unlock")
                .orynFont(.orynCaption, color: .orynTextTertiary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.bottom, Spacing.xs)

            ForEach(previewHints, id: \.self) { hint in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orynTextTertiary)
                    Text(hint)
                        .orynFont(.orynSubheadline, color: .orynTextTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynSurface.opacity(0.6))
        )
    }

    private let previewHints = [
        "Best hours for focused work",
        "How sleep affects your output",
        "Task completion streak",
        "Evening productivity patterns",
    ]
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: Insight

    private var accentColor: Color {
        switch insight.type {
        case .peak:        return .orynAccent
        case .sleep:       return Color(red: 0.38, green: 0.61, blue: 0.92)
        case .consistency: return .orynSuccess
        case .energy:      return .orynReschedule
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: insight.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(accentColor)
                }
                Text(insight.title)
                    .orynFont(.orynHeadline)
                Spacer()
            }

            if let highlight = insight.highlight {
                Text(highlight)
                    .orynFont(.orynTitle2)
                    .foregroundColor(accentColor)
            }

            Text(insight.body)
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let bars = insight.chartBars, !bars.isEmpty {
                InsightBarChart(bars: bars, accentColor: accentColor)
                    .frame(height: 56)
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
    }
}

// MARK: - Bar Chart

private struct InsightBarChart: View {
    let bars: [ChartBar]
    let accentColor: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(bars) { bar in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(bar.isHighlighted ? accentColor : Color.orynTextTertiary.opacity(0.25))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(4, 40 * bar.value))
                        .animation(.orynSmooth, value: bar.value)
                    Text(bar.label)
                        .font(.system(size: 9))
                        .foregroundColor(bar.isHighlighted ? accentColor : .orynTextTertiary)
                }
            }
        }
    }
}

// MARK: - Stat Pill

private struct InsightStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .orynFont(.orynTitle2)
            Text(label)
                .orynFont(.orynCaption, color: .orynTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
    }
}

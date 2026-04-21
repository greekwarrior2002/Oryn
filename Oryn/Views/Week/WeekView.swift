import SwiftUI

struct WeekView: View {
    @EnvironmentObject var store: TaskStore
    @Binding var showAddTask: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("SCHEDULE")
                        .orynFont(.orynCaption, color: .orynTextSecondary)
                        .tracking(1.5)
                    Text("This Week")
                        .orynFont(.orynLargeTitle)
                }
                .padding(.top, Spacing.xl)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)

                if store.scheduledDays.isEmpty {
                    WeekEmptyState(showAddTask: $showAddTask)
                        .padding(.top, Spacing.xxl)
                } else {
                    ForEach(store.scheduledDays) { day in
                        WeekDaySection(day: day)
                            .padding(.horizontal, Spacing.md)
                            .environmentObject(store)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .background(Color.orynBackground.ignoresSafeArea())
        .animation(.orynSmooth, value: store.scheduledDays.map(\.id))
    }
}

// MARK: - Empty state for week view

private struct WeekEmptyState: View {
    @Binding var showAddTask: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(LinearGradient(
                    colors: [.orynAccent, .orynSuccess],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: Spacing.sm) {
                Text("Nothing scheduled yet")
                    .orynFont(.orynTitle2)
                Text("Add tasks with deadlines and Oryn will plan your week.")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            OrynButton("Add a task", style: .primary, icon: "plus") {
                HapticManager.shared.light()
                showAddTask = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.md)
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var insightsStore: InsightsStore
    @State private var selectedTab: Tab = .today
    @State private var showAddTask = false
    @State private var showScanner = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("dailyCapHours") private var dailyCapHours: Double = 4.0

    enum Tab: Int, Hashable {
        case today, week, insights, settings
    }

    init() {
        // Hide the native UITabBar so our custom one takes over
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView(showAddTask: $showAddTask, showScanner: $showScanner)
                    .tag(Tab.today)

                WeekView(showAddTask: $showAddTask)
                    .tag(Tab.week)

                InsightsView()
                    .tag(Tab.insights)

                SettingsView()
                    .tag(Tab.settings)
            }

            CustomTabBar(selected: $selectedTab, showAddTask: $showAddTask)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showAddTask) {
            AddTaskView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showScanner) {
            ImageScannerView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { shown in
                if !shown {
                    hasSeenOnboarding = true
                    store.updateDailyCap(Int(dailyCapHours * 60))
                }
            }
        )) {
            OnboardingView(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { shown in if !shown { hasSeenOnboarding = true } }
            ))
        }
        .onChange(of: dailyCapHours) { _, hours in
            store.updateDailyCap(Int(hours * 60))
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selected: ContentView.Tab
    @Binding var showAddTask: Bool

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.today,    icon: "sun.max.fill",   label: "Today")
            tabItem(.week,     icon: "calendar",        label: "Week")
            addButton
            tabItem(.insights, icon: "chart.bar.fill",  label: "Insights")
            tabItem(.settings, icon: "gearshape.fill",  label: "Settings")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(
            Rectangle()
                .fill(Material.ultraThin)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -4)
        )
    }

    private func tabItem(_ tab: ContentView.Tab, icon: String, label: String) -> some View {
        let isSelected = selected == tab
        return Button {
            HapticManager.shared.light()
            withAnimation(.orynSpring) { selected = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .orynAccent : .orynTextTertiary)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.orynSpring, value: isSelected)
                Text(label)
                    .orynFont(.orynCaption, color: isSelected ? .orynAccent : .orynTextTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button {
            HapticManager.shared.medium()
            showAddTask = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.orynAccent)
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.orynAccent.opacity(0.35), radius: 10, x: 0, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .offset(y: -14)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

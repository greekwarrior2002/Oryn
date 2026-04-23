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
        case today, week, inbox, insights, settings
    }

    init() {
        // Hide the native UITabBar so our custom one takes over
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // LazyTabContent defers initialisation until first selection,
                // reducing startup work for rarely-visited tabs.
                LazyTabContent(isSelected: selectedTab == .today) {
                    TodayView(showAddTask: $showAddTask, showScanner: $showScanner)
                }
                .tag(Tab.today)

                LazyTabContent(isSelected: selectedTab == .week) {
                    WeekView(showAddTask: $showAddTask)
                }
                .tag(Tab.week)

                LazyTabContent(isSelected: selectedTab == .inbox) {
                    InboxView(showAddTask: $showAddTask)
                }
                .tag(Tab.inbox)

                LazyTabContent(isSelected: selectedTab == .insights) {
                    InsightsView()
                }
                .tag(Tab.insights)

                LazyTabContent(isSelected: selectedTab == .settings) {
                    SettingsView()
                }
                .tag(Tab.settings)
            }

            CustomTabBar(selected: $selectedTab, showAddTask: $showAddTask)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showAddTask) {
            // Inbox-first quick capture is the default entry point.
            QuickAddTaskView()
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
                    // Explicit cap update after onboarding completes.
                    store.updateDailyCap(Int(dailyCapHours * 60))
                }
            }
        )) {
            OnboardingView(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { shown in if !shown { hasSeenOnboarding = true } }
            ))
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selected: ContentView.Tab
    @Binding var showAddTask: Bool
    @EnvironmentObject var store: TaskStore

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.today,    icon: "sun.max.fill",               label: "Today")
            tabItem(.week,     icon: "calendar",                   label: "Week")
            addButton
            inboxTabItem
            tabItem(.insights, icon: "sparkles",                   label: "Insights")
            tabItem(.settings, icon: "gearshape.fill",             label: "Settings")
        }
        .padding(.horizontal, Spacing.md)
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
                    .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .orynAccent : .orynTextTertiary)
                    .scaleEffect(isSelected ? 1.06 : 1.0)
                    .animation(.orynSpring, value: isSelected)
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .orynAccent : .orynTextTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    /// Inbox tab shows a count badge for captured tasks.
    private var inboxTabItem: some View {
        let isSelected = selected == .inbox
        let count = store.inboxTasks.count
        return Button {
            HapticManager.shared.light()
            withAnimation(.orynSpring) { selected = .inbox }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .orynAccent : .orynTextTertiary)
                        .scaleEffect(isSelected ? 1.06 : 1.0)
                        .animation(.orynSpring, value: isSelected)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orynAccent))
                            .offset(x: 10, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text("Inbox")
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .orynAccent : .orynTextTertiary)
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
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.orynAccent.opacity(0.35), radius: 10, x: 0, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .offset(y: -12)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Capture a task")
    }
}

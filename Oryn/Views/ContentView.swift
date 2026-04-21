import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @State private var selectedTab: Tab = .today
    @State private var showAddTask = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("dailyCapHours") private var dailyCapHours: Double = 4.0

    enum Tab: Int {
        case today, week, settings
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabView(selection: $selectedTab) {
                TodayView(showAddTask: $showAddTask)
                    .tag(Tab.today)
                    .environmentObject(store)

                WeekView(showAddTask: $showAddTask)
                    .tag(Tab.week)
                    .environmentObject(store)

                SettingsView()
                    .tag(Tab.settings)
                    .environmentObject(store)
            }
            // Hide default tab bar — we render a custom one
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom tab bar
            CustomTabBar(selected: $selectedTab, showAddTask: $showAddTask)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 {
                hasSeenOnboarding = true
                // Sync daily cap from AppStorage to TaskStore
                store.updateDailyCap(Int(dailyCapHours * 60))
            }}
        )) {
            OnboardingView(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
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
            tabItem(.today, icon: "sun.max.fill", label: "Today")
            // Center Add button
            addButton
            tabItem(.week, icon: "calendar", label: "Week")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Material.ultraThin)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        )
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    private func tabItem(_ tab: ContentView.Tab, icon: String, label: String) -> some View {
        Button {
            HapticManager.shared.light()
            withAnimation(.orynSpring) { selected = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selected == tab ? .semibold : .regular))
                    .foregroundColor(selected == tab ? .orynAccent : .orynTextTertiary)
                    .scaleEffect(selected == tab ? 1.08 : 1.0)
                    .animation(.orynSpring, value: selected)
                Text(label)
                    .orynFont(.orynCaption,
                              color: selected == tab ? .orynAccent : .orynTextTertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var addButton: some View {
        Button {
            HapticManager.shared.medium()
            showAddTask = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.orynAccent)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.orynAccent.opacity(0.4), radius: 10, x: 0, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .offset(y: -10)
    }
}

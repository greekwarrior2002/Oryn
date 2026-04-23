import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var healthKit: HealthKitManager
    @StateObject private var notifications = NotificationManager.shared
    @AppStorage("dailyCapHours") private var dailyCapHours: Double = 4.0
    @State private var sliderDebounce: Task<Void, Never>? = nil

    // Notification toggles — backed by NotificationSettings enum
    @State private var notifyDueToday = NotificationSettings.notifyDueToday
    @State private var notifyOverdue  = NotificationSettings.notifyOverdue
    @State private var notifyEvening  = NotificationSettings.notifyEvening
    @State private var reminderHour   = NotificationSettings.reminderHour

    var body: some View {
        NavigationStack {
            List {
                schedulingSection
                integrationsSection
                notificationsSection
                healthSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 90)
            }
        }
    }

    // MARK: - Integrations & Suggestions

    private var integrationsSection: some View {
        Section {
            NavigationLink {
                IntegrationsView()
                    .environmentObject(store)
            } label: {
                Label("Integrations", systemImage: "link")
            }
            NavigationLink {
                SuggestionsView()
                    .environmentObject(store)
            } label: {
                Label("Suggestions", systemImage: "sparkles")
            }
        } header: {
            Text("Smart features")
        } footer: {
            Text("Connect Outlook or Google Calendar to see suggested tasks based on your schedule.")
        }
    }

    // MARK: - Scheduling

    private var schedulingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Daily limit")
                        .orynFont(.orynSubheadline)
                    Spacer()
                    Text(capLabel)
                        .orynFont(.orynSubheadline, color: .orynAccent)
                }
                Slider(value: $dailyCapHours, in: 1...10, step: 0.5)
                    .accentColor(.orynAccent)
                    .onChange(of: dailyCapHours) { _, hours in
                        sliderDebounce?.cancel()
                        sliderDebounce = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.4))
                            guard !Task.isCancelled else { return }
                            store.updateDailyCap(Int(hours * 60))
                        }
                    }
                Text("How many hours Oryn will schedule per day.")
                    .orynFont(.orynCaption, color: .orynTextSecondary)
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            Text("Scheduling")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            switch notifications.authorizationStatus {
            case .authorized:
                authorizedNotificationControls

            case .notDetermined:
                Button("Enable Notifications") {
                    Task { await notifications.requestAuthorization() }
                }
                .foregroundColor(.orynAccent)
                Text("Oryn can remind you about tasks due today and overdue work.")
                    .orynFont(.orynCaption, color: .orynTextSecondary)

            case .denied:
                HStack {
                    Image(systemName: "bell.slash.fill")
                        .foregroundColor(.red)
                    Text("Notifications disabled")
                        .orynFont(.orynSubheadline)
                    Spacer()
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.orynAccent)
                }

            default:
                Text("Notifications unavailable on this device.")
                    .orynFont(.orynCaption, color: .orynTextSecondary)
            }
        } header: {
            Text("Notifications")
        }
    }

    @ViewBuilder
    private var authorizedNotificationControls: some View {
        Toggle("Due today (morning briefing)", isOn: $notifyDueToday)
            .tint(.orynAccent)
            .onChange(of: notifyDueToday) { _, v in
                NotificationSettings.notifyDueToday = v
                notifications.rescheduleNotifications(for: store.tasks)
            }

        if notifyDueToday {
            HStack {
                Text("Reminder time")
                    .orynFont(.orynSubheadline)
                Spacer()
                Picker("", selection: $reminderHour) {
                    ForEach(6..<13) { h in
                        Text(hourLabel(h)).tag(h)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(.orynAccent)
                .onChange(of: reminderHour) { _, h in
                    NotificationSettings.reminderHour = h
                    notifications.rescheduleNotifications(for: store.tasks)
                }
            }
        }

        Toggle("Overdue reminders (11 AM)", isOn: $notifyOverdue)
            .tint(.orynAccent)
            .onChange(of: notifyOverdue) { _, v in
                NotificationSettings.notifyOverdue = v
                notifications.rescheduleNotifications(for: store.tasks)
            }

        Toggle("Evening nudge (6 PM)", isOn: $notifyEvening)
            .tint(.orynAccent)
            .onChange(of: notifyEvening) { _, v in
                NotificationSettings.notifyEvening = v
                notifications.rescheduleNotifications(for: store.tasks)
            }
    }

    // MARK: - Health

    private var healthSection: some View {
        Section {
            HStack {
                Label("Sleep & Activity", systemImage: "heart.fill")
                    .orynFont(.orynSubheadline)
                Spacer()
                switch healthKit.authorizationStatus {
                case .authorized:
                    Text("Connected")
                        .orynFont(.orynSubheadline, color: .orynSuccess)
                case .denied:
                    Text("Denied")
                        .orynFont(.orynSubheadline, color: .red)
                case .unavailable:
                    Text("Unavailable")
                        .orynFont(.orynSubheadline, color: .orynTextTertiary)
                case .notDetermined:
                    Button("Connect") {
                        Task { await healthKit.requestAuthorization() }
                    }
                    .foregroundColor(.orynAccent)
                }
            }

            if healthKit.authorizationStatus == .authorized {
                HStack {
                    Text("Last readiness")
                        .orynFont(.orynSubheadline)
                    Spacer()
                    Text("\(healthKit.readiness.value) · \(healthKit.readiness.level.label)")
                        .orynFont(.orynSubheadline, color: .orynTextSecondary)
                }
                Button("Refresh Health Data") {
                    Task { await healthKit.fetchHealthData(ignoreThrottle: true) }
                }
                .foregroundColor(.orynAccent)
            }

            Text("Oryn reads sleep and steps to adapt your daily schedule. No health data is stored or shared.")
                .orynFont(.orynCaption, color: .orynTextSecondary)
        } header: {
            Text("Health")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .orynFont(.orynSubheadline)
                Spacer()
                Text("1.1.0")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
            }
            HStack {
                Text("Tasks tracked")
                    .orynFont(.orynSubheadline)
                Spacer()
                Text("\(store.tasks.count)")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
            }
            HStack {
                Text("In inbox")
                    .orynFont(.orynSubheadline)
                Spacer()
                Text("\(store.backlogTasks.count)")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private var capLabel: String {
        let h = Int(dailyCapHours)
        let m = Int((dailyCapHours - Double(h)) * 60)
        return m == 0 ? "\(h)h / day" : "\(h)h \(m)m / day"
    }

    private func hourLabel(_ h: Int) -> String {
        let label = h <= 12 ? "\(h) AM" : "\(h - 12) PM"
        return label
    }
}

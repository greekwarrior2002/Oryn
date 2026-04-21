import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var healthKit: HealthKitManager
    @AppStorage("dailyCapHours") private var dailyCapHours: Double = 4.0
    // Debounce task so redistribute only runs after the slider settles
    @State private var sliderDebounce: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            List {
                // MARK: Scheduling
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
                                // Debounce: wait 0.4 s after the last tick before redistributing
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

                // MARK: Health
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

                // MARK: About
                Section {
                    HStack {
                        Text("Version")
                            .orynFont(.orynSubheadline)
                        Spacer()
                        Text("1.0.0")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    }

                    HStack {
                        Text("Tasks tracked")
                            .orynFont(.orynSubheadline)
                        Spacer()
                        Text("\(store.tasks.count)")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            // Push content above the floating custom tab bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 90)
            }
        }
    }

    private var capLabel: String {
        let h = Int(dailyCapHours)
        let m = Int((dailyCapHours - Double(h)) * 60)
        if m == 0 { return "\(h)h / day" }
        return "\(h)h \(m)m / day"
    }

}

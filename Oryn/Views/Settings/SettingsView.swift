import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TaskStore
    @AppStorage("dailyCapHours") private var dailyCapHours: Double = 4.0
    @AppStorage("workStartHour") private var workStartHour: Double = 9.0
    @AppStorage("workEndHour") private var workEndHour: Double = 18.0

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
                                let minutes = Int(hours * 60)
                                store.updateDailyCap(minutes)
                            }

                        Text("How many hours Oryn will schedule per day.")
                            .orynFont(.orynCaption, color: .orynTextSecondary)
                    }
                    .padding(.vertical, Spacing.xs)
                } header: {
                    Text("Scheduling")
                }

                // MARK: Work Hours
                Section {
                    HStack {
                        Label("Start", systemImage: "sunrise.fill")
                            .orynFont(.orynSubheadline)
                        Spacer()
                        Picker("", selection: $workStartHour) {
                            ForEach(Array(stride(from: 5.0, through: 12.0, by: 0.5)), id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accentColor(.orynAccent)
                    }

                    HStack {
                        Label("End", systemImage: "sunset.fill")
                            .orynFont(.orynSubheadline)
                        Spacer()
                        Picker("", selection: $workEndHour) {
                            ForEach(Array(stride(from: 12.0, through: 23.0, by: 0.5)), id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accentColor(.orynAccent)
                    }

                    Text("Used for future time-block scheduling.")
                        .orynFont(.orynCaption, color: .orynTextSecondary)
                } header: {
                    Text("Work Hours")
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
        }
    }

    private var capLabel: String {
        let h = Int(dailyCapHours)
        let m = Int((dailyCapHours - Double(h)) * 60)
        if m == 0 { return "\(h)h / day" }
        return "\(h)h \(m)m / day"
    }

    private func hourLabel(_ hour: Double) -> String {
        let h = Int(hour)
        let m = Int((hour - Double(h)) * 60)
        let period = h < 12 ? "AM" : "PM"
        let displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h)
        if m == 0 { return "\(displayH):00 \(period)" }
        return "\(displayH):\(String(format: "%02d", m)) \(period)"
    }
}

import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var durationMinutes = 30
    @State private var priority: Priority = .medium
    @State private var energyLevel: EnergyLevel = .medium
    @State private var energyInferred = false
    @State private var showValidationError = false

    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Task name — large, prominent, auto-focused
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("What needs to be done?", text: $title, axis: .vertical)
                            .orynFont(.orynTitle2)
                            .focused($titleFocused)
                            .lineLimit(1...4)
                            .submitLabel(.done)
                            .onChange(of: title) { _, newTitle in
                                if showValidationError && !newTitle.isEmpty {
                                    withAnimation(.orynSmooth) { showValidationError = false }
                                }
                                let inferred = EnergyLevel.inferred(from: newTitle)
                                if inferred != energyLevel {
                                    withAnimation(.orynSpring) {
                                        energyLevel = inferred
                                        energyInferred = true
                                    }
                                }
                            }

                        if showValidationError {
                            Text("Please enter a task name.")
                                .orynFont(.orynCaption, color: .red)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.top, Spacing.xs)

                    Divider()

                    // Deadline
                    RowLabel(title: "Deadline", icon: "calendar") {
                        DatePicker(
                            "",
                            selection: $deadline,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .accentColor(.orynAccent)
                    }

                    Divider()

                    // Duration
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Duration")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                        DurationPickerView(selected: $durationMinutes)
                    }

                    Divider()

                    // Priority
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Priority")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                        PriorityPickerView(selected: $priority)
                    }

                    Divider()

                    // Energy
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: Spacing.xs) {
                            Text("Energy needed")
                                .orynFont(.orynSubheadline, color: .orynTextSecondary)
                            if energyInferred {
                                Text("· inferred")
                                    .orynFont(.orynCaption, color: .orynTextTertiary)
                                    .transition(.opacity)
                            }
                        }
                        EnergyPickerView(selected: $energyLevel)
                            .onChange(of: energyLevel) { _, _ in
                                energyInferred = false
                            }
                    }

                    Spacer(minLength: Spacing.xl)

                    // Schedule CTA
                    Button {
                        submitTask()
                    } label: {
                        Text("Schedule")
                            .orynFont(.orynButton, color: .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .fill(title.trimmingCharacters(in: .whitespaces).isEmpty
                                          ? Color.orynAccent.opacity(0.4)
                                          : Color.orynAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .animation(.orynSmooth, value: title.isEmpty)
                }
                .padding(Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.orynBackground.ignoresSafeArea())
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                    .foregroundColor(.orynTextSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Slight delay so the sheet animation completes before focusing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleFocused = true
            }
        }
    }

    private func submitTask() {
        let cleaned = title.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else {
            HapticManager.shared.error()
            withAnimation(.orynSmooth) { showValidationError = true }
            return
        }
        HapticManager.shared.success()
        SoundManager.shared.playAdd()
        store.addTask(
            title: cleaned,
            deadline: deadline,
            durationMinutes: durationMinutes,
            priority: priority,
            energyLevel: energyLevel
        )
        dismiss()
    }
}

// MARK: - Row Label helper

struct RowLabel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .orynFont(.orynSubheadline)
            Spacer()
            content
        }
    }
}

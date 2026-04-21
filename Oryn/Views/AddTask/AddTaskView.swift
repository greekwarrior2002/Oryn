import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var isBacklog = false
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var durationMinutes = 30
    @State private var priority: Priority = .medium
    @State private var energyLevel: EnergyLevel = .medium
    @State private var energyInferred = false
    @State private var showValidationError = false

    // Recurrence
    @State private var recurrenceRule: RecurrenceRule? = nil
    @State private var recurrenceCustomDays: [Int] = []

    // Scheduling controls
    @State private var schedulePinnedDate: Date? = nil
    @State private var scheduleNotBeforeDate: Date? = nil
    @State private var isLocked = false
    @State private var showSchedulingControls = false

    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title
                    titleSection

                    Divider()

                    // Backlog toggle
                    backlogRow

                    if !isBacklog {
                        Divider()
                        deadlineRow
                        Divider()
                        durationSection
                    }

                    Divider()

                    prioritySection

                    Divider()

                    energySection

                    Divider()

                    // Recurrence
                    recurrenceSection

                    if !isBacklog {
                        Divider()
                        schedulingSection
                    }

                    Spacer(minLength: Spacing.xl)

                    submitButton
                }
                .padding(Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.orynBackground.ignoresSafeArea())
            .navigationTitle(isBacklog ? "Add to Inbox" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                    .foregroundColor(.orynTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isBacklog ? "Capture" : "Add") { submitTask() }
                        .fontWeight(.semibold)
                        .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? .orynTextTertiary : .orynAccent)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .animation(.orynSmooth, value: title.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { titleFocused = true }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("What needs to be done?", text: $title, axis: .vertical)
                .orynFont(.orynTitle2)
                .focused($titleFocused)
                .lineLimit(1...4)
                .submitLabel(.done)
                .onSubmit { submitTask() }
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
    }

    private var backlogRow: some View {
        Toggle(isOn: $isBacklog.animation(.orynSmooth)) {
            Label("Add to inbox (plan later)", systemImage: "tray.fill")
                .orynFont(.orynSubheadline)
        }
        .tint(.orynAccent)
    }

    private var deadlineRow: some View {
        RowLabel(title: "Deadline", icon: "calendar") {
            DatePicker("", selection: $deadline, in: Date()..., displayedComponents: .date)
                .labelsHidden()
                .accentColor(.orynAccent)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Duration")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
            DurationPickerView(selected: $durationMinutes)
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Priority")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
            PriorityPickerView(selected: $priority)
        }
    }

    private var energySection: some View {
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
                .onChange(of: energyLevel) { _, _ in energyInferred = false }
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Repeat")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
            RecurrencePickerView(rule: $recurrenceRule, customDays: $recurrenceCustomDays)
        }
    }

    private var schedulingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                HapticManager.shared.light()
                withAnimation(.orynSmooth) { showSchedulingControls.toggle() }
            } label: {
                HStack {
                    Text("Scheduling options")
                        .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    Spacer()
                    Image(systemName: showSchedulingControls ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.orynTextTertiary)
                }
            }
            .buttonStyle(.plain)

            if showSchedulingControls {
                SchedulingControlsView(
                    pinnedDate: $schedulePinnedDate,
                    notBeforeDate: $scheduleNotBeforeDate,
                    isLocked: $isLocked
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var submitButton: some View {
        Button { submitTask() } label: {
            Text(isBacklog ? "Capture to Inbox" : "Schedule")
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

    // MARK: - Submit

    private func submitTask() {
        let cleaned = title.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else {
            HapticManager.shared.error()
            withAnimation(.orynSmooth) { showValidationError = true }
            return
        }
        HapticManager.shared.success()
        SoundManager.shared.playAdd()

        if isBacklog {
            store.addBacklogTask(title: cleaned)
        } else {
            store.addTask(
                title: cleaned,
                deadline: deadline,
                durationMinutes: durationMinutes,
                priority: priority,
                energyLevel: energyLevel,
                recurrenceRule: recurrenceRule,
                recurrenceCustomDays: recurrenceCustomDays,
                schedulePinnedDate: schedulePinnedDate,
                scheduleNotBeforeDate: scheduleNotBeforeDate,
                isLocked: isLocked
            )
        }
        dismiss()
    }
}

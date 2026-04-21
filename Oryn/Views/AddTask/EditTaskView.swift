import SwiftUI

struct EditTaskView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) var dismiss

    let task: OrynTask

    @State private var title: String
    @State private var deadline: Date
    @State private var durationMinutes: Int
    @State private var priority: Priority
    @State private var energyLevel: EnergyLevel
    @State private var showValidationError = false

    // Recurrence
    @State private var recurrenceRule: RecurrenceRule?
    @State private var recurrenceCustomDays: [Int]

    // Scheduling controls
    @State private var schedulePinnedDate: Date?
    @State private var scheduleNotBeforeDate: Date?
    @State private var isLocked: Bool
    @State private var showSchedulingControls = false

    init(task: OrynTask) {
        self.task = task
        _title               = State(initialValue: task.title)
        _deadline            = State(initialValue: task.deadline)
        _durationMinutes     = State(initialValue: task.durationMinutes)
        _priority            = State(initialValue: task.priority)
        _energyLevel         = State(initialValue: task.energyLevel)
        _recurrenceRule      = State(initialValue: task.recurrenceRule)
        _recurrenceCustomDays = State(initialValue: task.recurrenceCustomDays)
        _schedulePinnedDate  = State(initialValue: task.schedulePinnedDate)
        _scheduleNotBeforeDate = State(initialValue: task.scheduleNotBeforeDate)
        _isLocked            = State(initialValue: task.isLocked)
        // Expand controls if any were already set
        let hasControls = task.schedulePinnedDate != nil
            || task.scheduleNotBeforeDate != nil
            || task.isLocked
        _showSchedulingControls = State(initialValue: hasControls)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    titleSection
                    Divider()
                    deadlineRow
                    Divider()
                    durationSection
                    Divider()
                    prioritySection
                    Divider()
                    energySection
                    Divider()
                    recurrenceSection
                    Divider()
                    schedulingSection

                    if let label = task.recurrenceLabel, !task.isCompleted {
                        recurrenceInfoRow(label: label)
                    }

                    Spacer(minLength: Spacing.xl)
                    saveButton
                }
                .padding(Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.orynBackground.ignoresSafeArea())
            .navigationTitle("Edit Task")
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
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                        .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? .orynTextTertiary : .orynAccent)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("What needs to be done?", text: $title, axis: .vertical)
                .orynFont(.orynTitle2)
                .lineLimit(1...4)
                .submitLabel(.done)
                .onChange(of: title) { _, newTitle in
                    if showValidationError && !newTitle.isEmpty {
                        withAnimation(.orynSmooth) { showValidationError = false }
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
            Text("Energy needed")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
            EnergyPickerView(selected: $energyLevel)
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
                    if schedulePinnedDate != nil || scheduleNotBeforeDate != nil || isLocked {
                        Circle()
                            .fill(Color.orynAccent)
                            .frame(width: 6, height: 6)
                    }
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

    private func recurrenceInfoRow(label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11))
                .foregroundColor(.orynAccent)
            Text("Repeats: \(label)")
                .orynFont(.orynCaption, color: .orynTextSecondary)
        }
    }

    private var saveButton: some View {
        Button { saveChanges() } label: {
            Text("Save Changes")
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

    // MARK: - Save

    private func saveChanges() {
        let cleaned = title.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else {
            HapticManager.shared.error()
            withAnimation(.orynSmooth) { showValidationError = true }
            return
        }
        HapticManager.shared.success()
        store.updateTask(
            task,
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
        dismiss()
    }
}

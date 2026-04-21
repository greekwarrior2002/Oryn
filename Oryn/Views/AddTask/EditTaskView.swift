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

    init(task: OrynTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _deadline = State(initialValue: task.deadline)
        _durationMinutes = State(initialValue: task.durationMinutes)
        _priority = State(initialValue: task.priority)
        _energyLevel = State(initialValue: task.energyLevel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
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

                    Divider()

                    RowLabel(title: "Deadline", icon: "calendar") {
                        DatePicker("", selection: $deadline, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                            .accentColor(.orynAccent)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Duration")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                        DurationPickerView(selected: $durationMinutes)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Priority")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                        PriorityPickerView(selected: $priority)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Energy needed")
                            .orynFont(.orynSubheadline, color: .orynTextSecondary)
                        EnergyPickerView(selected: $energyLevel)
                    }

                    Spacer(minLength: Spacing.xl)

                    Button {
                        saveChanges()
                    } label: {
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
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? .orynTextTertiary : .orynAccent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

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
            energyLevel: energyLevel
        )
        dismiss()
    }
}

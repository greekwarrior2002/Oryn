import SwiftUI

/// Shows the AI-parsed task list so the user can review, edit, and confirm before saving.
struct ScanPreviewView: View {
    @EnvironmentObject var store: TaskStore
    @Binding var tasks: [ParsedTask]
    let onDismiss: () -> Void

    @State private var appeared: Set<UUID> = []
    @State private var showSuccess = false
    @State private var addedCount  = 0
    @State private var showDuplicateWarning = false
    @State private var duplicateTitles: [String] = []

    private var selectedCount: Int { tasks.filter(\.isSelected).count }

    var body: some View {
        ZStack {
            Color.orynBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                controlBar
                Divider()
                taskList
            }

            VStack {
                Spacer()
                bottomBar
            }

            if showSuccess { successOverlay }
        }
        .navigationTitle("Review Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showSuccess)
        .alert("Possible Duplicates", isPresented: $showDuplicateWarning) {
            Button("Import Anyway") { performImport() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let titles = duplicateTitles.prefix(3).joined(separator: ", ")
            Text("These tasks look similar to ones you already have: \(titles). Import anyway?")
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack {
            Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s") detected")
                .orynFont(.orynCaption, color: .orynTextSecondary)
            Spacer()
            Button {
                HapticManager.shared.selectionChanged()
                let all = tasks.allSatisfy(\.isSelected)
                withAnimation(.orynSpring) {
                    for i in tasks.indices { tasks[i].isSelected = !all }
                }
            } label: {
                Text(tasks.allSatisfy(\.isSelected) ? "Deselect all" : "Select all")
                    .orynFont(.orynCaption, color: .orynAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(tasks.indices, id: \.self) { index in
                    taskRow(at: index)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            if selectedCount > 0 {
                Button(action: checkAndImport) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Add \(selectedCount) Task\(selectedCount == 1 ? "" : "s")")
                            .orynFont(.orynButton, color: .white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.orynAccent))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .padding(.top, Spacing.sm)
        .background(
            Rectangle()
                .fill(Material.ultraThin)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.orynSpring, value: selectedCount)
    }

    // MARK: - Success overlay

    private var successOverlay: some View {
        ZStack {
            Color.orynBackground.opacity(0.92).ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.orynSuccessSoft)
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.orynSuccess)
                }
                .scaleEffect(showSuccess ? 1.0 : 0.5)
                .animation(.orynBounce, value: showSuccess)

                VStack(spacing: Spacing.xs) {
                    Text("\(addedCount) task\(addedCount == 1 ? "" : "s") added!")
                        .orynFont(.orynTitle2)
                    Text("Scheduled and ready to go.")
                        .orynFont(.orynSubheadline, color: .orynTextSecondary)
                }
                .opacity(showSuccess ? 1 : 0)
                .animation(.orynSmooth.delay(0.15), value: showSuccess)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Import logic

    private func checkAndImport() {
        let selected = tasks.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        // Duplicate detection: check for very similar titles in existing tasks
        let existingTitles = store.tasks.map { $0.title.lowercased() }
        let potentialDups = selected.filter { parsed in
            let lc = parsed.title.lowercased()
            return existingTitles.contains { existing in
                // Simple overlap check: titles share ≥ 70% of words
                let parsedWords   = Set(lc.split(separator: " ").map(String.init))
                let existingWords = Set(existing.split(separator: " ").map(String.init))
                guard !parsedWords.isEmpty else { return false }
                let overlap = parsedWords.intersection(existingWords).count
                return Double(overlap) / Double(parsedWords.count) >= 0.7
            }
        }

        if !potentialDups.isEmpty {
            duplicateTitles = potentialDups.map(\.title)
            showDuplicateWarning = true
        } else {
            performImport()
        }
    }

    private func performImport() {
        let selected = tasks.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        HapticManager.shared.success()
        addedCount = selected.count

        for task in selected {
            store.addTask(
                title: task.title,
                deadline: task.deadline ?? Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
                durationMinutes: task.durationMinutes,
                priority: task.priority,
                energyLevel: EnergyLevel.inferred(from: task.title)
            )
        }

        withAnimation(.orynSmooth) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            HapticManager.shared.light()
            onDismiss()
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func taskRow(at index: Int) -> some View {
        let task = tasks[index]
        ParsedTaskRow(
            task: binding(for: task.id),
            appeared: appeared.contains(task.id),
            onDelete: { deleteTask(at: index) }
        )
        .onAppear {
            let delay = Double(index) * 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.orynBounce) { _ = appeared.insert(task.id) }
            }
        }
    }

    private func deleteTask(at index: Int) {
        withAnimation(.orynSpring) {
            guard tasks.indices.contains(index) else { return }
            tasks.remove(at: index)
        }
    }

    private func binding(for id: UUID) -> Binding<ParsedTask> {
        let fallback = ParsedTask(title: "", durationMinutes: 30, priority: .medium)
        return Binding<ParsedTask>(
            get: { self.tasks.first(where: { $0.id == id }) ?? fallback },
            set: { newVal in
                if let idx = self.tasks.firstIndex(where: { $0.id == id }) {
                    self.tasks[idx] = newVal
                }
            }
        )
    }
}

// MARK: - Parsed Task Row

private struct ParsedTaskRow: View {
    @Binding var task: ParsedTask
    let appeared: Bool
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var showDetailEditor = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            selectionButton

            VStack(alignment: .leading, spacing: Spacing.xs) {
                titleArea
                metaRow
            }

            Spacer()

            // Edit button for full detail editing
            Button {
                HapticManager.shared.light()
                showDetailEditor = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .foregroundColor(.orynTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.orynSurface))
        .orynCardShadow()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showDetailEditor) {
            ParsedTaskDetailEditor(task: $task)
        }
    }

    // MARK: - Sub-components

    private var selectionButton: some View {
        Button {
            HapticManager.shared.selectionChanged()
            withAnimation(.orynSpring) { task.isSelected.toggle() }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(task.isSelected ? Color.orynAccent : Color.orynTextTertiary, lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                if task.isSelected {
                    Circle()
                        .fill(Color.orynAccent)
                        .frame(width: 14, height: 14)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var titleArea: some View {
        Group {
            if isEditing {
                TextField("Task title", text: $editTitle)
                    .orynFont(.orynHeadline)
                    .submitLabel(.done)
                    .onSubmit { commitEdit() }
            } else {
                Text(task.title)
                    .orynFont(.orynHeadline)
                    .strikethrough(!task.isSelected, color: .orynTextTertiary)
                    .foregroundColor(task.isSelected ? .orynTextPrimary : .orynTextSecondary)
                    .onTapGesture(count: 2) { startEditing() }
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: Spacing.sm) {
            metaChip(icon: "clock", label: durationLabel(task.durationMinutes), color: .orynTextSecondary)

            if task.priority != .medium {
                metaChip(icon: task.priority.icon, label: task.priority.label, color: task.priority.color)
            }

            if let dl = task.deadlineLabel {
                metaChip(icon: "calendar", label: dl, color: .orynAccent)
            }
        }
    }

    private func startEditing() {
        editTitle = task.title
        withAnimation(.orynSmooth) { isEditing = true }
    }

    private func commitEdit() {
        let cleaned = editTitle.trimmingCharacters(in: .whitespaces)
        if !cleaned.isEmpty { task.title = cleaned }
        withAnimation(.orynSmooth) { isEditing = false }
    }

    private func durationLabel(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h" : "\(minutes)m"
    }

    private func metaChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10, weight: .medium))
            Text(label).orynFont(.orynCaption)
        }
        .foregroundColor(color)
    }
}

// MARK: - Parsed Task Detail Editor

private struct ParsedTaskDetailEditor: View {
    @Binding var task: ParsedTask
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var durationMinutes: Int
    @State private var priority: Priority
    @State private var deadline: Date

    init(task: Binding<ParsedTask>) {
        _task            = task
        _title           = State(initialValue: task.wrappedValue.title)
        _durationMinutes = State(initialValue: task.wrappedValue.durationMinutes)
        _priority        = State(initialValue: task.wrappedValue.priority)
        _deadline        = State(initialValue: task.wrappedValue.deadline
                                 ?? Calendar.current.date(byAdding: .day, value: 3, to: Date())!)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Task title", text: $title, axis: .vertical)
                            .orynFont(.orynTitle2)
                            .lineLimit(1...3)
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
                        Text("Duration").orynFont(.orynSubheadline, color: .orynTextSecondary)
                        DurationPickerView(selected: $durationMinutes)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Priority").orynFont(.orynSubheadline, color: .orynTextSecondary)
                        PriorityPickerView(selected: $priority)
                    }

                    Spacer(minLength: Spacing.xl)

                    Button {
                        let cleaned = title.trimmingCharacters(in: .whitespaces)
                        if !cleaned.isEmpty { task.title = cleaned }
                        task.durationMinutes = durationMinutes
                        task.priority        = priority
                        task.deadline        = deadline
                        dismiss()
                    } label: {
                        Text("Apply")
                            .orynFont(.orynButton, color: .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.orynAccent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.orynBackground.ignoresSafeArea())
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.orynTextSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

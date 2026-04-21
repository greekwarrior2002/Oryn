import SwiftUI

/// Shows the AI-parsed task list so the user can review, edit, and confirm before saving.
struct ScanPreviewView: View {
    @EnvironmentObject var store: TaskStore
    @Binding var tasks: [ParsedTask]
    let onDismiss: () -> Void

    @State private var appeared: Set<UUID> = []
    @State private var showSuccess = false
    @State private var addedCount = 0

    private var selectedCount: Int { tasks.filter(\.isSelected).count }

    var body: some View {
        ZStack {
            Color.orynBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Subtitle bar
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

                Divider()

                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { (index, task) in
                            ParsedTaskRow(
                                task: binding(for: task.id),
                                appeared: appeared.contains(task.id)
                            )
                            .onAppear {
                                let delay = Double(index) * 0.06
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    withAnimation(.orynBounce) {
                                        appeared.insert(task.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, 120)
                }
            }

            // Fixed bottom action bar
            VStack {
                Spacer()
                bottomBar
            }

            // Success flash
            if showSuccess {
                successOverlay
            }
        }
        .navigationTitle("Review Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showSuccess)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            if selectedCount > 0 {
                Button(action: importSelected) {
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

    // MARK: - Import action

    private func importSelected() {
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

        // Auto-dismiss after a short celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            HapticManager.shared.light()
            onDismiss()
        }
    }

    // MARK: - Binding helper

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

    @State private var isEditing = false
    @State private var editTitle = ""

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Selection circle
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

            VStack(alignment: .leading, spacing: Spacing.xs) {
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

                HStack(spacing: Spacing.sm) {
                    // Duration
                    metaChip(icon: "clock", label: durationLabel(task.durationMinutes),
                             color: .orynTextSecondary)

                    // Priority (only when not medium)
                    if task.priority != .medium {
                        metaChip(icon: task.priority.icon,
                                 label: task.priority.label,
                                 color: task.priority.color)
                    }

                    // Deadline label
                    if let dl = task.deadlineLabel {
                        metaChip(icon: "calendar", label: dl, color: .orynAccent)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynSurface)
        )
        .orynCardShadow()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Edit support

    private func startEditing() {
        editTitle = task.title
        withAnimation(.orynSmooth) { isEditing = true }
    }

    private func commitEdit() {
        let cleaned = editTitle.trimmingCharacters(in: .whitespaces)
        if !cleaned.isEmpty { task.title = cleaned }
        withAnimation(.orynSmooth) { isEditing = false }
    }

    // MARK: - Helpers

    private func durationLabel(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h" : "\(minutes)m"
    }

    private func metaChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(label)
                .orynFont(.orynCaption)
        }
        .foregroundColor(color)
    }
}

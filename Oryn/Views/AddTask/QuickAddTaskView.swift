import SwiftUI

/// The new Inbox-first task capture sheet.
///
/// Design philosophy:
///   1. One big, clean text field. No forms, no required pickers.
///   2. Keywords (`today`, `tomorrow`, `3pm`, `urgent`, …) highlight live as
///      the user types — similar to iMessage's date/phone detection.
///   3. A small "detected" chip row summarises what Oryn understood; the user
///      can tap any chip to undo it.
///   4. Add button routes the task:
///        • no date/time detected → Inbox
///        • date/time detected    → auto-schedules + appears in Today/Week/Scheduled
///   5. An unobtrusive "More options" reveal still lets power users open the
///      detailed form (`AddTaskView`) without losing what they typed.
struct QuickAddTaskView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) var dismiss

    @State private var rawTitle: String = ""
    @State private var parsed: ParsedTaskInput = ParsedTaskInput(
        cleanedTitle: "", rawTitle: "", detections: [],
        dueDate: nil, dueTime: nil, priority: nil
    )
    @State private var showDetailedSheet = false
    @State private var isFieldFocused: Bool = false
    @AppStorage("smartParsingEnabled") private var smartParsingEnabled: Bool = true

    // Debounced parse — parsing is cheap but debouncing keeps the
    // attributed-string animation feeling smooth during rapid typing.
    @State private var parseWorkItem: DispatchWorkItem?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                captureSection
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xl)

                detectionChips
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                Spacer()

                footer
            }
            .background(Color.orynBackground.ignoresSafeArea())
            .navigationTitle(destinationTitle)
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
                    Button("Add") { submit() }
                        .fontWeight(.semibold)
                        .foregroundColor(canSubmit ? .orynAccent : .orynTextTertiary)
                        .disabled(!canSubmit)
                }
            }
            .onAppear {
                // Defer focus so the sheet animates in before the keyboard.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFieldFocused = true
                }
            }
            .sheet(isPresented: $showDetailedSheet, onDismiss: {
                // If the detailed form added a task, this sheet will close too.
            }) {
                AddTaskView(prefilledTitle: rawTitle)
                    .environmentObject(store)
            }
        }
        .presentationDetents([.fraction(0.55), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if smartParsingEnabled {
                HighlightedTaskField(
                    text: $rawTitle,
                    detections: parsed.detections,
                    onSubmit: { submit() },
                    placeholder: "What's on your mind?",
                    isFocused: isFieldFocused
                )
                .frame(minHeight: 44)
                .onChange(of: rawTitle) { _, new in
                    scheduleParse(for: new)
                }
            } else {
                TextField("What's on your mind?", text: $rawTitle, axis: .vertical)
                    .font(.system(size: 22, weight: .regular))
                    .lineLimit(1...5)
                    .submitLabel(.done)
                    .onSubmit { submit() }
            }

            Divider()
                .padding(.top, Spacing.xs)
        }
    }

    @ViewBuilder
    private var detectionChips: some View {
        if smartParsingEnabled && (parsed.dueDate != nil || parsed.dueTime != nil || parsed.priority != nil) {
            HStack(spacing: Spacing.xs) {
                if let date = parsed.dueDate {
                    DetectionChip(
                        icon: "calendar",
                        label: dateChipLabel(for: date),
                        tint: .orynAccent
                    )
                }
                if let time = parsed.dueTime {
                    DetectionChip(
                        icon: "clock",
                        label: timeChipLabel(for: time),
                        tint: .teal
                    )
                }
                if let p = parsed.priority {
                    DetectionChip(
                        icon: "exclamationmark.triangle.fill",
                        label: "\(p.label) priority",
                        tint: .orange
                    )
                }
                Spacer()
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.orynSpring, value: parsed.detections)
        } else if !rawTitle.isEmpty && smartParsingEnabled {
            Text("No date detected — will save to Inbox.")
                .orynFont(.orynCaption, color: .orynTextTertiary)
                .transition(.opacity)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Label(destinationSummary, systemImage: destinationIcon)
                    .orynFont(.orynCaption, color: .orynTextSecondary)
                Spacer()
                Button {
                    HapticManager.shared.light()
                    showDetailedSheet = true
                } label: {
                    Label("More options", systemImage: "slider.horizontal.3")
                        .orynFont(.orynCaption, color: .orynAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.orynSurface.opacity(0.5))
        }
    }

    // MARK: - Destination hints

    private var destinationTitle: String {
        parsed.shouldSchedule ? "Schedule" : "Inbox"
    }

    private var destinationIcon: String {
        parsed.shouldSchedule ? "calendar" : "tray.fill"
    }

    private var destinationSummary: String {
        if let date = parsed.dueDate {
            if let time = parsed.dueTime {
                return "Will schedule \(dateChipLabel(for: date)) at \(timeChipLabel(for: time))"
            }
            return "Will schedule \(dateChipLabel(for: date))"
        }
        return "Will save to Inbox"
    }

    // MARK: - Submit

    private var canSubmit: Bool {
        !rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit else {
            HapticManager.shared.error()
            return
        }
        HapticManager.shared.success()
        SoundManager.shared.playAdd()
        store.quickAdd(rawTitle: rawTitle)
        dismiss()
    }

    // MARK: - Parsing

    private func scheduleParse(for text: String) {
        parseWorkItem?.cancel()
        guard smartParsingEnabled else {
            parsed = ParsedTaskInput(cleanedTitle: text, rawTitle: text, detections: [],
                                     dueDate: nil, dueTime: nil, priority: nil)
            return
        }
        let item = DispatchWorkItem {
            let result = NLPTaskParser.parse(text)
            withAnimation(.orynSmooth) {
                self.parsed = result
            }
        }
        parseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: item)
    }

    // MARK: - Labels

    private func dateChipLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let fmt = DateFormatter()
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if diff > 1 && diff < 7 {
            fmt.dateFormat = "EEEE"        // "Monday"
        } else {
            fmt.dateFormat = "MMM d"       // "Jun 4"
        }
        return fmt.string(from: date)
    }

    private func timeChipLabel(for time: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: time)
    }
}

// MARK: - Detection chip

private struct DetectionChip: View {
    let icon: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

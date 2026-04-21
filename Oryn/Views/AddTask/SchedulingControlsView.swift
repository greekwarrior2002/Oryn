import SwiftUI

/// Inline scheduling constraint controls used in Add/Edit task flows.
struct SchedulingControlsView: View {
    @Binding var pinnedDate: Date?
    @Binding var notBeforeDate: Date?
    @Binding var isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            pinRow
            if pinnedDate != nil {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { pinnedDate ?? Date() },
                        set: { pinnedDate = $0 }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .accentColor(.orynAccent)
                .padding(.leading, Spacing.lg + Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            notBeforeRow
            if notBeforeDate != nil {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { notBeforeDate ?? Date() },
                        set: { notBeforeDate = $0 }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .accentColor(.orynAccent)
                .padding(.leading, Spacing.lg + Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            lockRow
            if isLocked {
                Text("Oryn won't move this task during auto-scheduling.")
                    .orynFont(.orynCaption, color: .orynTextSecondary)
                    .padding(.leading, Spacing.lg + Spacing.sm)
                    .transition(.opacity)
            }
        }
        .animation(.orynSmooth, value: pinnedDate != nil)
        .animation(.orynSmooth, value: notBeforeDate != nil)
        .animation(.orynSmooth, value: isLocked)
    }

    // MARK: - Rows

    private var pinRow: some View {
        Toggle(isOn: Binding(
            get: { pinnedDate != nil },
            set: { on in
                pinnedDate = on
                    ? (Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                    : nil
            }
        )) {
            Label("Pin to specific day", systemImage: "pin.fill")
                .orynFont(.orynSubheadline)
        }
        .tint(.orynAccent)
    }

    private var notBeforeRow: some View {
        Toggle(isOn: Binding(
            get: { notBeforeDate != nil },
            set: { on in
                notBeforeDate = on
                    ? (Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                    : nil
            }
        )) {
            Label("Don't schedule before", systemImage: "calendar.badge.exclamationmark")
                .orynFont(.orynSubheadline)
        }
        .tint(.orynAccent)
    }

    private var lockRow: some View {
        Toggle(isOn: $isLocked) {
            Label("Lock in place", systemImage: "lock.fill")
                .orynFont(.orynSubheadline)
        }
        .tint(.orynAccent)
    }
}

import SwiftUI

struct RecurrencePickerView: View {
    @Binding var rule: RecurrenceRule?
    @Binding var customDays: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ruleButton(nil)
            ForEach(RecurrenceRule.allCases, id: \.rawValue) { r in
                ruleButton(r)
                if r == .custom && rule == .custom {
                    customDaySelector
                        .padding(.leading, Spacing.lg + Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.orynSpring, value: rule)
    }

    // MARK: - Rule Button

    private func ruleButton(_ r: RecurrenceRule?) -> some View {
        Button {
            HapticManager.shared.selectionChanged()
            withAnimation(.orynSpring) { rule = r }
        } label: {
            HStack(spacing: Spacing.sm) {
                if let r {
                    Image(systemName: r.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(rule == r ? .orynAccent : .orynTextSecondary)
                        .frame(width: 18)
                    Text(r.label)
                        .orynFont(.orynSubheadline)
                        .foregroundColor(rule == r ? .orynTextPrimary : .orynTextSecondary)
                } else {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(rule == nil ? .orynAccent : .orynTextSecondary)
                        .frame(width: 18)
                    Text("No recurrence")
                        .orynFont(.orynSubheadline)
                        .foregroundColor(rule == nil ? .orynTextPrimary : .orynTextSecondary)
                }
                Spacer()
                if rule == r {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orynAccent)
                }
            }
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Day Picker

    // Calendar.weekday convention: 1=Sun, 2=Mon, …, 7=Sat
    private let weekdays: [(Int, String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    private var customDaySelector: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(weekdays, id: \.0) { wd, label in
                let isOn = customDays.contains(wd)
                Button {
                    HapticManager.shared.selectionChanged()
                    withAnimation(.orynSpring) {
                        if isOn {
                            customDays.removeAll { $0 == wd }
                        } else {
                            customDays.append(wd)
                        }
                    }
                } label: {
                    Text(label)
                        .orynFont(.orynCaption)
                        .foregroundColor(isOn ? .white : .orynTextSecondary)
                        .frame(width: 38, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(isOn ? Color.orynAccent : Color.orynSurfaceSecondary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

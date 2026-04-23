import SwiftUI

/// Review queue for suggested tasks from Outlook / Google Calendar / heuristics.
///
/// The queue feels like a lightweight triage surface — each card has a single
/// "Add" tap and a "Dismiss" tap. Nothing is silently inserted into the task
/// list. Accepted suggestions use the normal quick-add pipeline so they inherit
/// keyword parsing and smart view routing automatically.
struct SuggestionsView: View {
    @EnvironmentObject var store: TaskStore
    @StateObject private var suggestionStore = SuggestionStore.shared
    @StateObject private var outlook = OutlookService.shared
    @StateObject private var gcal = GoogleCalendarService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    headerBanner
                    if suggestionStore.suggestions.isEmpty {
                        emptyState
                    } else {
                        ForEach(suggestionStore.suggestions) { s in
                            SuggestionCard(
                                suggestion: s,
                                onAdd:     { suggestionStore.accept(s, into: store) },
                                onDismiss: { suggestionStore.dismiss(s) }
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, 120)
            }
            .background(Color.orynBackground.ignoresSafeArea())
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if suggestionStore.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(suggestionStore.isRefreshing)
                }
            }
            .refreshable { await refresh() }
            .task { await refresh() }
        }
    }

    // MARK: - Sections

    private var headerBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundColor(.orynAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Smart suggestions")
                    .orynFont(.orynSubheadline)
                Text("Review before they're added.")
                    .orynFont(.orynCaption, color: .orynTextSecondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynAccent.opacity(0.08))
        )
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(colors: [.orynAccent, .orynSuccess],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("All caught up")
                .orynFont(.orynTitle2)
            if !outlook.isConnected && !gcal.isConnected {
                Text("Connect Outlook or Google Calendar in Settings to surface helpful suggestions.")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            } else {
                Text("No new suggestions. We'll surface items automatically.")
                    .orynFont(.orynSubheadline, color: .orynTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Actions

    private func refresh() async {
        let providers: [IntegrationProvider] = [outlook, gcal]
        await suggestionStore.refresh(providers: providers, existingTasks: store.tasks)
    }
}

// MARK: - Suggestion Card

private struct SuggestionCard: View {
    let suggestion: TaskSuggestion
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .orynFont(.orynHeadline)
                    if let note = suggestion.note, !note.isEmpty {
                        Text(note)
                            .orynFont(.orynCaption, color: .orynTextSecondary)
                            .lineLimit(2)
                    }
                    if let date = suggestion.suggestedDate {
                        Text(dateLabel(date))
                            .orynFont(.orynCaption, color: .orynAccent)
                    }
                }
                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                Button {
                    HapticManager.shared.success()
                    onAdd()
                } label: {
                    Label("Add", systemImage: "plus")
                        .orynFont(.orynCaption, color: .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orynAccent))
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.shared.light()
                    onDismiss()
                } label: {
                    Text("Dismiss")
                        .orynFont(.orynCaption, color: .orynTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(Color.orynTextTertiary, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.orynSurface)
                .orynCardShadow()
        )
    }

    private var icon: String {
        switch suggestion.kind {
        case .calendarPrep, .calendarFollowUp: return "calendar"
        case .email: return "envelope"
        case .deadline: return "clock.badge.exclamationmark"
        case .general: return "sparkles"
        }
    }

    private var tint: Color {
        switch suggestion.kind {
        case .calendarPrep, .calendarFollowUp: return .orynAccent
        case .email: return .teal
        case .deadline: return .orange
        case .general: return .orynAccent
        }
    }

    private func dateLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Suggested for today" }
        if cal.isDateInTomorrow(d) { return "Suggested for tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return "Suggested for \(f.string(from: d))"
    }
}

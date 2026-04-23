import Foundation

/// Turns raw `IntegrationCandidate`s into review-worthy `TaskSuggestion`s.
///
/// The engine is intentionally conservative:
///   • Calendar events within the next 48h may generate a "Prepare for" task
///     if they look non-trivial (length > 30 min, has a location or body).
///   • Unread emails whose subject contains imperative-action keywords
///     ("action required", "please review", "deadline", "invoice", "due by")
///     generate a "Respond to" task.
///   • Existing `OrynTask.externalRef` matches and the user's dismissal list
///     keep the queue from resurfacing the same items.
///
/// Adjust the heuristics below — keep them selective so the queue never feels
/// spammy. Everything lands in `SuggestionStore`; nothing inserts directly.
enum SuggestionEngine {

    private static let emailActionKeywords = [
        "action required", "please review", "please respond", "deadline",
        "invoice", "due by", "due:", "asap", "urgent", "rsvp", "confirm"
    ]

    static func buildSuggestions(
        from candidates: [IntegrationCandidate],
        existingTasks: [OrynTask],
        dismissedFingerprints: Set<String>,
        now: Date = Date()
    ) -> [TaskSuggestion] {
        let existingRefs = Set(existingTasks.compactMap { $0.externalRef })

        var results: [TaskSuggestion] = []
        for c in candidates {
            guard !existingRefs.contains(c.id) else { continue }
            if let s = suggestion(from: c, now: now) {
                if !dismissedFingerprints.contains(s.fingerprint) {
                    results.append(s)
                }
            }
        }
        return results
    }

    private static func suggestion(from c: IntegrationCandidate, now: Date) -> TaskSuggestion? {
        switch c.kind {
        case .calendarEvent:
            return calendarSuggestion(from: c, now: now)
        case .email:
            return emailSuggestion(from: c)
        case .reminder:
            return TaskSuggestion(
                id: UUID().uuidString,
                kind: .general,
                sourceProviderID: c.providerID,
                externalRef: c.id,
                title: c.title,
                note: c.body,
                suggestedDate: c.deadline,
                suggestedTime: c.start,
                createdAt: Date()
            )
        }
    }

    private static func calendarSuggestion(from c: IntegrationCandidate, now: Date) -> TaskSuggestion? {
        guard let start = c.start else { return nil }
        // Only consider upcoming events within the next 48h.
        let interval = start.timeIntervalSince(now)
        guard interval > 0, interval < 60 * 60 * 48 else { return nil }

        // Suggest prep for non-trivial events only.
        let duration = c.end.map { $0.timeIntervalSince(start) } ?? 0
        let bodySignal = (c.body?.count ?? 0) > 40
        guard duration >= 30 * 60 || bodySignal else { return nil }

        let cal = Calendar.current
        let dayBefore = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: start)) ?? now
        return TaskSuggestion(
            id: UUID().uuidString,
            kind: .calendarPrep,
            sourceProviderID: c.providerID,
            externalRef: c.id,
            title: "Prepare for: \(c.title)",
            note: c.body,
            suggestedDate: max(dayBefore, cal.startOfDay(for: now)),
            suggestedTime: nil,
            createdAt: Date()
        )
    }

    private static func emailSuggestion(from c: IntegrationCandidate) -> TaskSuggestion? {
        let lower = (c.title + " " + (c.body ?? "")).lowercased()
        guard emailActionKeywords.contains(where: { lower.contains($0) }) else { return nil }
        return TaskSuggestion(
            id: UUID().uuidString,
            kind: .email,
            sourceProviderID: c.providerID,
            externalRef: c.id,
            title: "Respond to: \(c.title)",
            note: c.body,
            suggestedDate: nil,
            suggestedTime: nil,
            createdAt: Date()
        )
    }
}

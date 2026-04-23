import Foundation

/// A suggested task pending user review.
///
/// Suggestions are produced by `SuggestionEngine` from integration data
/// (calendar events, emails) or from heuristic nudges ("meeting tomorrow →
/// prepare"). They deliberately sit in a review queue before becoming real
/// tasks so users never feel overwhelmed by auto-imported items.
struct TaskSuggestion: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, Hashable {
        case calendarPrep      // "Prepare for: <event title>"
        case calendarFollowUp  // "Follow up on: <event title>"
        case email             // "Respond to: <subject>"
        case deadline          // "Deadline: <title>"
        case general
    }

    var id: String
    var kind: Kind
    var sourceProviderID: String     // "outlook", "gcal", or "local"
    var externalRef: String?         // event id / message id — used for dedup
    var title: String                // The task title we will insert
    var note: String?                // Contextual body preview
    var suggestedDate: Date?
    var suggestedTime: Date?
    var createdAt: Date

    /// Used to persist dismissals so we don't resurface the same suggestion.
    var fingerprint: String {
        "\(sourceProviderID):\(externalRef ?? title):\(kind.rawValue)"
    }
}

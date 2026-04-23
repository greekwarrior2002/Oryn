import Foundation

/// A connected external source (Outlook, Google Calendar, …) that can feed
/// items into Oryn's task system. Integrations are intentionally thin —
/// they fetch items and hand them to `SuggestionEngine` for review, rather
/// than inserting tasks directly. Keeps the "no surprise" promise.
protocol IntegrationProvider: AnyObject {
    /// A short stable identifier, e.g. "outlook" or "gcal".
    var id: String { get }
    /// Display name for settings and review queue.
    var displayName: String { get }
    /// SF Symbol used in the UI.
    var icon: String { get }
    /// Whether the provider has a valid connection (OAuth token stored).
    var isConnected: Bool { get }

    /// Present a sign-in flow and store the resulting credentials. Currently a
    /// stub in each concrete provider — see each file for what still needs
    /// wiring (client IDs, callback URLs, etc.).
    func connect() async throws
    /// Disconnect and revoke stored credentials.
    func disconnect() async

    /// Fetch raw candidate items. The suggestion engine decides which ones
    /// surface as reviewable suggestions.
    func fetchCandidates() async throws -> [IntegrationCandidate]
}

/// A raw item returned by an integration — either a calendar event or a
/// message that might imply an actionable task. The suggestion engine may
/// reject, transform, or surface these based on user settings.
struct IntegrationCandidate: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case calendarEvent
        case email
        case reminder
    }
    let id: String           // External stable ID (e.g. iCal UID, Graph message id)
    let providerID: String   // "outlook", "gcal", …
    let kind: Kind
    let title: String
    let body: String?
    let start: Date?
    let end: Date?
    let deadline: Date?
    let url: URL?
}

/// Errors surfaced by integration providers. Keep messages user-friendly —
/// they may be shown directly in Settings.
enum IntegrationError: LocalizedError {
    case notConfigured(String)
    case notConnected
    case authFailed(String)
    case networkFailure(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let detail): return "Not configured: \(detail)"
        case .notConnected:              return "Not connected."
        case .authFailed(let detail):    return "Sign-in failed: \(detail)"
        case .networkFailure(let detail):return "Network error: \(detail)"
        case .unsupported(let detail):   return "Unsupported: \(detail)"
        }
    }
}

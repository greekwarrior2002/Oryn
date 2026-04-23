import SwiftUI
import Combine

/// Holds the review queue of pending `TaskSuggestion`s and the set of dismissed
/// fingerprints so the same item never resurfaces.
///
/// The store is deliberately in-memory + UserDefaults-backed rather than part
/// of SwiftData — suggestions are ephemeral by design, and we want them to be
/// cheap to refresh on sign-in / pull-to-refresh without touching the primary
/// task model.
@MainActor
final class SuggestionStore: ObservableObject {

    static let shared = SuggestionStore()

    @Published private(set) var suggestions: [TaskSuggestion] = []
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastError: String? = nil

    private var dismissed: Set<String> {
        didSet { UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissedKey) }
    }
    private static let dismissedKey = "oryn.suggestions.dismissed"

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? []
        self.dismissed = Set(saved)
    }

    // MARK: - Public API

    /// Refresh suggestions by pulling candidates from every connected provider
    /// and running them through the suggestion engine.
    func refresh(providers: [IntegrationProvider], existingTasks: [OrynTask]) async {
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        var allCandidates: [IntegrationCandidate] = []
        for p in providers where p.isConnected {
            do {
                let c = try await p.fetchCandidates()
                allCandidates.append(contentsOf: c)
            } catch {
                lastError = error.localizedDescription
            }
        }

        let fresh = SuggestionEngine.buildSuggestions(
            from: allCandidates,
            existingTasks: existingTasks,
            dismissedFingerprints: dismissed
        )
        withAnimation(.orynSmooth) {
            self.suggestions = fresh
        }
    }

    /// Accept a suggestion — insert it as a normal task via `TaskStore.quickAdd`.
    func accept(_ suggestion: TaskSuggestion, into store: TaskStore) {
        let base = suggestion.title
        let dateSuffix: String
        if let d = suggestion.suggestedDate {
            let cal = Calendar.current
            if cal.isDateInToday(d) { dateSuffix = " today" }
            else if cal.isDateInTomorrow(d) { dateSuffix = " tomorrow" }
            else {
                let f = DateFormatter(); f.dateFormat = "EEEE"
                dateSuffix = " \(f.string(from: d))"
            }
        } else {
            dateSuffix = ""
        }
        let compiled = base + dateSuffix

        // Route through the normal parse-aware pipeline so behavior is
        // consistent with manual captures.
        let task = store.quickAdd(rawTitle: compiled, source: sourceForProvider(suggestion.sourceProviderID))
        task?.externalRef = suggestion.externalRef
        remove(suggestion, dismissPermanently: false)
    }

    /// Dismiss without adding. Fingerprinted so it doesn't come back.
    func dismiss(_ suggestion: TaskSuggestion) {
        dismissed.insert(suggestion.fingerprint)
        remove(suggestion, dismissPermanently: true)
    }

    func clearAll() {
        suggestions.removeAll()
    }

    // MARK: - Helpers

    private func remove(_ suggestion: TaskSuggestion, dismissPermanently: Bool) {
        withAnimation(.orynSmooth) {
            suggestions.removeAll { $0.id == suggestion.id }
        }
    }

    private func sourceForProvider(_ providerID: String) -> TaskSource {
        switch providerID {
        case "outlook": return .outlook
        case "gcal":    return .gcal
        default:        return .suggestion
        }
    }
}

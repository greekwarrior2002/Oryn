import Foundation

// MARK: - Productivity summary passed to AI

struct ProductivitySummary {
    let totalCompletions: Int
    let daysTracked: Int
    let peakHour: Int?           // most common completion hour
    let onTimeRatePct: Int       // 0–100
    let currentStreak: Int       // consecutive days
    let avgSleepHours: Double    // 0 if no HealthKit data
    let sleepDataAvailable: Bool
    let eveningPct: Int          // % of tasks done after 8 PM
}

// MARK: - Protocol

protocol AIInsightsService {
    func generateInsights(from summary: ProductivitySummary) async throws -> [Insight]
}

// MARK: - Claude API service
//
// SETUP: Set your Anthropic API key in the constant below.
// Get a key at https://console.anthropic.com/
// Leave it empty ("") to fall back to the rule-based engine automatically.

final class ClaudeInsightsService: AIInsightsService {

    // ⚠️  Replace with your actual Anthropic API key before shipping.
    // For development, you can also set the ANTHROPIC_API_KEY environment variable.
    private static let apiKey: String = {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }()

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"

    var isConfigured: Bool { !Self.apiKey.isEmpty }

    func generateInsights(from summary: ProductivitySummary) async throws -> [Insight] {
        guard isConfigured else { throw AIInsightsError.notConfigured }

        let prompt = buildPrompt(from: summary)
        let requestBody: [String: Any] = [
            "model": Self.model,
            "max_tokens": 500,
            "messages": [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIInsightsError.networkError
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw AIInsightsError.invalidAPIKey }
            if http.statusCode == 429 { throw AIInsightsError.rateLimited }
            throw AIInsightsError.serverError(http.statusCode)
        }

        return try parseResponse(data: data, summary: summary)
    }

    // MARK: - Prompt construction

    private func buildPrompt(from s: ProductivitySummary) -> String {
        var lines: [String] = [
            "You are analyzing a user's productivity patterns in a task planner app.",
            "Generate 1–3 concise, personalized insights based on the data below.",
            "",
            "DATA:",
            "- Tasks completed: \(s.totalCompletions)",
            "- Days tracked: \(s.daysTracked)",
            "- On-time completion rate: \(s.onTimeRatePct)%",
            "- Current daily streak: \(s.currentStreak) day(s)",
            "- % of tasks done after 8 PM: \(s.eveningPct)%",
        ]
        if let peak = s.peakHour {
            lines.append("- Most productive hour block: \(InsightsEngine.hourLabel(peak))–\(InsightsEngine.hourLabel(peak + 2))")
        }
        if s.sleepDataAvailable {
            lines.append(String(format: "- Average sleep (nights with data): %.1f hours", s.avgSleepHours))
        }
        lines += [
            "",
            "FORMAT: Return a JSON array of objects. Each object must have these exact keys:",
            "  icon (SF Symbol name), title (max 4 words), highlight (short stat or phrase), body (1–2 sentences)",
            "Example: [{\"icon\":\"bolt.fill\",\"title\":\"Peak Productivity\",\"highlight\":\"9–11 AM\",\"body\":\"Most tasks get done in the morning.\"}]",
            "Return only the JSON array, no other text.",
        ]
        return lines.joined(separator: "\n")
    }

    // MARK: - Response parsing

    private func parseResponse(data: Data, summary: ProductivitySummary) throws -> [Insight] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = (json["content"] as? [[String: Any]])?.first,
            let text = content["text"] as? String
        else { throw AIInsightsError.malformedResponse }

        // Extract JSON array from the model response (it may be wrapped in markdown)
        let cleaned = extractJSON(from: text)
        guard
            let jsonData = cleaned.data(using: .utf8),
            let items = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
        else { throw AIInsightsError.malformedResponse }

        return items.compactMap { item in
            guard
                let icon = item["icon"] as? String,
                let title = item["title"] as? String,
                let body = item["body"] as? String
            else { return nil }
            let highlight = item["highlight"] as? String
            return Insight(
                icon: icon,
                title: title,
                body: body,
                highlight: highlight,
                type: insightType(for: icon),
                chartBars: nil
            )
        }
    }

    private func extractJSON(from text: String) -> String {
        // Strip markdown code fences if present
        let stripped = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Find the first '[' and last ']'
        if let start = stripped.firstIndex(of: "["),
           let end = stripped.lastIndex(of: "]") {
            return String(stripped[start...end])
        }
        return stripped
    }

    private func insightType(for icon: String) -> InsightType {
        switch icon {
        case let i where i.contains("moon"):  return .sleep
        case let i where i.contains("flame"), let i where i.contains("checkmark"): return .consistency
        case let i where i.contains("bolt"):  return .peak
        default: return .energy
        }
    }
}

// MARK: - Errors

enum AIInsightsError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case rateLimited
    case networkError
    case serverError(Int)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "Anthropic API key not configured."
        case .invalidAPIKey:      return "Invalid Anthropic API key."
        case .rateLimited:        return "AI insights rate limited — using local analysis."
        case .networkError:       return "Network error fetching AI insights."
        case .serverError(let c): return "Server error \(c) from insights API."
        case .malformedResponse:  return "Unexpected response format from insights API."
        }
    }
}

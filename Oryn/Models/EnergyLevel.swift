import SwiftUI

enum EnergyLevel: Int, Codable, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var icon: String {
        switch self {
        case .low: return "battery.25"
        case .medium: return "battery.50"
        case .high: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .medium: return Color.orange.opacity(0.85)
        case .high: return Color(red: 0.196, green: 0.843, blue: 0.294)
        }
    }

    var sortWeight: Int { rawValue }

    static func inferred(from title: String) -> EnergyLevel {
        let lower = title.lowercased()
        let highKeywords = ["write", "plan", "design", "code", "build", "create",
                            "analyze", "review", "strategy", "research", "draft", "develop"]
        let lowKeywords  = ["email", "admin", "errand", "buy", "call", "check",
                            "send", "pay", "schedule", "book", "reply"]

        let words = lower.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            let base = word.trimmingCharacters(in: .punctuationCharacters)
            if highKeywords.contains(where: { base.hasPrefix($0) }) { return .high }
        }
        for word in words {
            let base = word.trimmingCharacters(in: .punctuationCharacters)
            if lowKeywords.contains(where: { base.hasPrefix($0) }) { return .low }
        }
        return .medium
    }
}

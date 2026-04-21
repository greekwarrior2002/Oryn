import SwiftUI

enum Priority: Int, Codable, CaseIterable, Identifiable {
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
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(.systemGray3)
        case .medium: return Color.orange.opacity(0.85)
        case .high: return Color.red.opacity(0.85)
        }
    }

    var sortWeight: Int { rawValue }
}

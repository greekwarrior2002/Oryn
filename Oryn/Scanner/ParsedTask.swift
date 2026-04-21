import Foundation

/// A task extracted from an OCR scan, ready for user review before saving.
struct ParsedTask: Identifiable {
    let id = UUID()
    var title: String
    var deadline: Date? = nil
    var deadlineLabel: String? = nil   // human-readable hint shown in preview ("Friday", "Tomorrow")
    var durationMinutes: Int
    var priority: Priority
    var isSelected: Bool = true
}

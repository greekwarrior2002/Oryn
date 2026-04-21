import Foundation

/// Converts raw OCR text lines into structured ParsedTask values.
final class TaskParserService {

    // MARK: - Public API

    func parse(lines: [String]) -> [ParsedTask] {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 1 }
            .map { parseLine($0) }
    }

    // MARK: - Core parsing

    private func parseLine(_ raw: String) -> ParsedTask {
        var text = raw
        var deadline: Date?
        var deadlineLabel: String?
        var durationMinutes = 30
        var priority: Priority = .medium

        text = stripBullets(text)
        priority = detectPriority(in: text)
        text = stripPriorityWords(from: text, priority: priority)
        (durationMinutes, text) = extractDuration(from: text)
        (deadline, deadlineLabel, text) = extractDeadline(from: text)
        text = normalizeWhitespace(text)
        text = capitalize(text)

        return ParsedTask(
            title: text,
            deadline: deadline,
            deadlineLabel: deadlineLabel,
            durationMinutes: durationMinutes,
            priority: priority
        )
    }

    // MARK: - Bullet stripping

    private func stripBullets(_ input: String) -> String {
        // Remove leading -, •, *, >, [x], [ ], ✓, numbers like "1."
        let pattern = #"^[\-•\*>\[\]x✓□✗0-9]+[\.\):\s]*\s*"#
        return input.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    // MARK: - Priority detection

    private let highWords = ["urgent", "asap", "important", "critical", "must", "!", "now", "today!!!"]
    private let lowWords  = ["maybe", "possibly", "if time", "low priority", "whenever", "someday", "eventually"]

    private func detectPriority(in text: String) -> Priority {
        let lower = text.lowercased()
        if highWords.contains(where: { lower.contains($0) }) { return .high }
        if lowWords.contains(where:  { lower.contains($0) }) { return .low  }
        return .medium
    }

    private func stripPriorityWords(from text: String, priority: Priority) -> String {
        var t = text
        let words = priority == .high ? highWords : (priority == .low ? lowWords : [])
        for word in words {
            t = t.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        // Strip trailing punctuation artefacts like "!!" or "()"
        t = t.replacingOccurrences(of: #"[!]{2,}"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\(\s*\)"#, with: "", options: .regularExpression)
        return t
    }

    // MARK: - Duration extraction

    // Matches: "2h", "2 h", "2hr", "2 hours", "30m", "30 min", "30 minutes", "1.5h"
    private let durationPattern = #"(\d+(?:\.\d+)?)\s*(hours?|hrs?|h\b|minutes?|mins?|m\b)"#

    private func extractDuration(from text: String) -> (Int, String) {
        guard let range = text.range(of: durationPattern, options: [.regularExpression, .caseInsensitive]) else {
            return (30, text)
        }
        let matchStr = String(text[range])
        let numStr   = matchStr.components(separatedBy: .whitespaces).first ?? ""
        let unit     = matchStr.lowercased()

        var minutes = 30
        if let num = Double(numStr) {
            let isHours = unit.contains("h")
            minutes = isHours ? Int(num * 60) : Int(num)
        }

        let cleaned = text.replacingCharacters(in: range, with: "")
        return (max(5, minutes), cleaned)
    }

    // MARK: - Deadline extraction

    private struct DayEntry {
        let pattern: String
        let label: String
        let offsetFromToday: Int   // positive = days ahead, -1 = "next occurrence of weekday"
        let weekdayNumber: Int     // 1=Sun, 2=Mon … used when offsetFromToday == -1
    }

    private let dayEntries: [DayEntry] = [
        .init(pattern: "\\btoday\\b",     label: "Today",     offsetFromToday: 0,  weekdayNumber: 0),
        .init(pattern: "\\btomorrow\\b",  label: "Tomorrow",  offsetFromToday: 1,  weekdayNumber: 0),
        .init(pattern: "\\bmonday\\b|\\bmon\\b",    label: "Monday",    offsetFromToday: -1, weekdayNumber: 2),
        .init(pattern: "\\btuesday\\b|\\btue\\b",   label: "Tuesday",   offsetFromToday: -1, weekdayNumber: 3),
        .init(pattern: "\\bwednesday\\b|\\bwed\\b", label: "Wednesday", offsetFromToday: -1, weekdayNumber: 4),
        .init(pattern: "\\bthursday\\b|\\bthu\\b",  label: "Thursday",  offsetFromToday: -1, weekdayNumber: 5),
        .init(pattern: "\\bfriday\\b|\\bfri\\b",    label: "Friday",    offsetFromToday: -1, weekdayNumber: 6),
        .init(pattern: "\\bsaturday\\b|\\bsat\\b",  label: "Saturday",  offsetFromToday: -1, weekdayNumber: 7),
        .init(pattern: "\\bsunday\\b|\\bsun\\b",    label: "Sunday",    offsetFromToday: -1, weekdayNumber: 1),
        // "next week"
        .init(pattern: "\\bnext\\s+week\\b", label: "Next Week", offsetFromToday: 7,  weekdayNumber: 0),
        // "this weekend"
        .init(pattern: "\\bweekend\\b",      label: "Weekend",   offsetFromToday: -1, weekdayNumber: 7),
    ]

    private func extractDeadline(from text: String) -> (Date?, String?, String) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        for entry in dayEntries {
            guard let range = text.range(of: entry.pattern, options: [.regularExpression, .caseInsensitive]) else {
                continue
            }
            let deadline: Date
            if entry.offsetFromToday >= 0 {
                deadline = cal.date(byAdding: .day, value: entry.offsetFromToday, to: today)!
            } else {
                let current  = cal.component(.weekday, from: today)
                var daysAhead = entry.weekdayNumber - current
                if daysAhead <= 0 { daysAhead += 7 }
                deadline = cal.date(byAdding: .day, value: daysAhead, to: today)!
            }
            let cleaned = text.replacingCharacters(in: range, with: "")
            return (deadline, entry.label, cleaned)
        }

        // Try "in X days"
        if let (days, range) = extractInNDays(from: text) {
            let deadline = cal.date(byAdding: .day, value: days, to: today)!
            let cleaned  = text.replacingCharacters(in: range, with: "")
            return (deadline, "In \(days) days", cleaned)
        }

        // No deadline found; default 3 days out
        let fallback = cal.date(byAdding: .day, value: 3, to: today)!
        return (fallback, nil, text)
    }

    private func extractInNDays(from text: String) -> (Int, Range<String.Index>)? {
        let pattern = #"\bin\s+(\d+)\s+days?\b"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let match = String(text[range])
        let numStr = match.components(separatedBy: .whitespaces).first(where: { Int($0) != nil }) ?? ""
        guard let days = Int(numStr) else { return nil }
        return (days, range)
    }

    // MARK: - Helpers

    private func normalizeWhitespace(_ input: String) -> String {
        input
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func capitalize(_ input: String) -> String {
        guard let first = input.first else { return input }
        return first.uppercased() + input.dropFirst()
    }
}

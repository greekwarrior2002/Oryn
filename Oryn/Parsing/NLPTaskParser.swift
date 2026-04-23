import Foundation

// MARK: - Detection

/// A single keyword match found in a task title.
/// `range` is an NSRange (UTF-16) so it can drive both String substring lookups and
/// `NSAttributedString` attribute ranges for live highlighting.
struct TaskDetection: Equatable {
    enum Kind: Equatable {
        case date       // "today", "tomorrow", "monday", "next friday"
        case time       // "3pm", "7:30", "noon"
        case priority   // "urgent", "asap", "high priority"
    }
    let range: NSRange
    let kind: Kind
    let matchedText: String
}

// MARK: - Parsed Result

struct ParsedTaskInput: Equatable {
    /// Cleaned title with parsed keywords removed (when it still reads naturally).
    let cleanedTitle: String
    /// Original raw title as typed by the user.
    let rawTitle: String
    /// Ranges (in raw title) that should be visually highlighted.
    let detections: [TaskDetection]

    let dueDate: Date?
    let dueTime: Date?
    let priority: Priority?

    var hasAnyDetection: Bool { !detections.isEmpty }
    /// A task should auto-schedule (leave the Inbox) when the user gave it a date or time.
    var shouldSchedule: Bool { dueDate != nil || dueTime != nil }
}

// MARK: - Parser

/// Extensible natural language task parser.
///
/// Detects date, time, and priority keywords inside a task title and returns a
/// `ParsedTaskInput` describing both the cleaned title and the metadata that
/// should be applied. The parser is pure / stateless so it can be safely called
/// on every keystroke for live highlighting.
///
/// To add new keywords, extend `DateKeywords`, `PriorityKeywords`, or the
/// `timeRegex` patterns below — no UI changes required.
enum NLPTaskParser {

    // MARK: Public API

    static func parse(_ title: String, now: Date = Date(), calendar: Calendar = .current) -> ParsedTaskInput {
        let raw = title
        var detections: [TaskDetection] = []
        var dueDate: Date?
        var dueTime: Date?
        var priority: Priority?

        // Order matters: we want to claim longer phrases ("this week", "next monday")
        // before shorter ones ("week", "monday"). Each helper returns ranges it
        // consumed so subsequent passes can skip them.
        var consumed = IndexSet()

        // 1. Priority keywords
        for phrase in PriorityKeywords.all {
            if let range = findPhrase(phrase.text, in: raw, excluding: consumed) {
                detections.append(.init(range: range, kind: .priority, matchedText: phrase.text))
                consumed.insert(integersIn: Range(range)!)
                if priority == nil { priority = phrase.priority }
            }
        }

        // 2. Time keywords ("noon", "midnight", "3pm", "7:30", "at 5")
        for detection in findTimes(in: raw, now: now, calendar: calendar, excluding: consumed) {
            detections.append(detection.detection)
            consumed.insert(integersIn: Range(detection.detection.range)!)
            if dueTime == nil { dueTime = detection.time }
        }

        // 3. Date keywords
        for detection in findDates(in: raw, now: now, calendar: calendar, excluding: consumed) {
            detections.append(detection.detection)
            consumed.insert(integersIn: Range(detection.detection.range)!)
            if dueDate == nil { dueDate = detection.date }
        }

        // Sort detections left-to-right so highlighting + cleanup are stable.
        detections.sort { $0.range.location < $1.range.location }

        let cleaned = cleanTitle(raw, removing: detections)

        // If the parser found a time but no date, assume "today" (e.g. "Call mom at 7pm").
        // This mirrors how people naturally speak — "at 7pm" implies today.
        if dueTime != nil && dueDate == nil {
            dueDate = calendar.startOfDay(for: now)
        }

        return ParsedTaskInput(
            cleanedTitle: cleaned,
            rawTitle: raw,
            detections: detections,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority
        )
    }

    // MARK: Date detection

    private struct DateHit { let detection: TaskDetection; let date: Date }

    private static func findDates(in text: String, now: Date, calendar: Calendar, excluding: IndexSet) -> [DateHit] {
        var hits: [DateHit] = []
        let today = calendar.startOfDay(for: now)

        // Static phrases first (ordered longest → shortest).
        for (phrase, resolver) in DateKeywords.phrases {
            if let range = findPhrase(phrase, in: text, excluding: excluding, consumedBy: hits),
               let date = resolver(today, calendar) {
                hits.append(.init(
                    detection: .init(range: range, kind: .date, matchedText: phrase),
                    date: date
                ))
            }
        }

        // Weekday names ("monday", "this monday", "next monday").
        for name in DateKeywords.weekdays {
            // "next <weekday>"
            if let range = findPhrase("next \(name)", in: text, excluding: excluding, consumedBy: hits) {
                let date = nextWeekday(named: name, after: today, calendar: calendar, preferNextWeek: true)
                hits.append(.init(
                    detection: .init(range: range, kind: .date, matchedText: "next \(name)"),
                    date: date
                ))
                continue
            }
            // "this <weekday>"
            if let range = findPhrase("this \(name)", in: text, excluding: excluding, consumedBy: hits) {
                let date = nextWeekday(named: name, after: today, calendar: calendar, preferNextWeek: false)
                hits.append(.init(
                    detection: .init(range: range, kind: .date, matchedText: "this \(name)"),
                    date: date
                ))
                continue
            }
            // bare "<weekday>"
            if let range = findPhrase(name, in: text, excluding: excluding, consumedBy: hits) {
                let date = nextWeekday(named: name, after: today, calendar: calendar, preferNextWeek: false)
                hits.append(.init(
                    detection: .init(range: range, kind: .date, matchedText: name),
                    date: date
                ))
            }
        }

        return hits
    }

    // MARK: Time detection

    private struct TimeHit { let detection: TaskDetection; let time: Date }

    private static let timeRegex: NSRegularExpression? = {
        // Matches: 3pm, 3 pm, 3:30pm, 3:30 pm, 15:30, at 5, at 5pm
        let pattern = #"(?i)\b(?:at\s+)?([0-1]?\d|2[0-3])(?::([0-5]\d))?\s?(am|pm)?\b"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    private static func findTimes(in text: String, now: Date, calendar: Calendar, excluding: IndexSet) -> [TimeHit] {
        var hits: [TimeHit] = []

        // 1. Special words: noon, midnight, tonight (tonight is fuzzy — treat as 19:00 hint only if no explicit time).
        if let range = findPhrase("noon", in: text, excluding: excluding) {
            hits.append(.init(
                detection: .init(range: range, kind: .time, matchedText: "noon"),
                time: timeDate(hour: 12, minute: 0, calendar: calendar)
            ))
        }
        if let range = findPhrase("midnight", in: text, excluding: excluding) {
            hits.append(.init(
                detection: .init(range: range, kind: .time, matchedText: "midnight"),
                time: timeDate(hour: 0, minute: 0, calendar: calendar)
            ))
        }

        // 2. Regex for HH/HH:MM + optional am/pm
        guard let regex = timeRegex else { return hits }
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let m = match else { return }
            let totalRange = m.range
            if rangeIsConsumed(totalRange, excluding: excluding, hits: hits) { return }

            // The hour captured is group 1; filter out false positives like "1" in "1 slide".
            // Require either a colon, an am/pm, or a leading "at" for a match to count.
            let matchedText = ns.substring(with: totalRange)
            let lower = matchedText.lowercased()

            let hasAmPm = lower.contains("am") || lower.contains("pm")
            let hasColon = lower.contains(":")
            let hasAt = lower.hasPrefix("at ")
            guard hasAmPm || hasColon || hasAt else { return }

            guard let hourStr = captureGroup(match: m, index: 1, in: ns),
                  var hour = Int(hourStr) else { return }
            let minuteStr = captureGroup(match: m, index: 2, in: ns) ?? "0"
            let minute = Int(minuteStr) ?? 0
            let ampm = captureGroup(match: m, index: 3, in: ns)?.lowercased()

            if ampm == "pm", hour < 12 { hour += 12 }
            if ampm == "am", hour == 12 { hour = 0 }

            guard hour >= 0 && hour <= 23, minute >= 0 && minute <= 59 else { return }

            hits.append(.init(
                detection: .init(range: totalRange, kind: .time, matchedText: matchedText),
                time: timeDate(hour: hour, minute: minute, calendar: calendar)
            ))
        }

        return hits
    }

    // MARK: Helpers

    private static func findPhrase(
        _ phrase: String,
        in text: String,
        excluding: IndexSet,
        consumedBy hits: [DateHit] = []
    ) -> NSRange? {
        let ns = text as NSString
        var searchFrom = 0
        while searchFrom < ns.length {
            let searchRange = NSRange(location: searchFrom, length: ns.length - searchFrom)
            let found = ns.range(of: phrase, options: [.caseInsensitive], range: searchRange)
            if found.location == NSNotFound { return nil }
            // Must be a whole-word match.
            if isWordBoundary(at: found, in: ns),
               !rangeIsConsumed(found, excluding: excluding, hits: hits) {
                return found
            }
            searchFrom = found.location + 1
        }
        return nil
    }

    private static func isWordBoundary(at range: NSRange, in ns: NSString) -> Bool {
        let alnum = CharacterSet.alphanumerics
        if range.location > 0 {
            let c = ns.character(at: range.location - 1)
            if let u = UnicodeScalar(c), alnum.contains(u) { return false }
        }
        let after = range.location + range.length
        if after < ns.length {
            let c = ns.character(at: after)
            if let u = UnicodeScalar(c), alnum.contains(u) { return false }
        }
        return true
    }

    private static func rangeIsConsumed(_ range: NSRange, excluding: IndexSet, hits: [DateHit]) -> Bool {
        guard let swiftRange = Range(range) else { return false }
        if excluding.intersects(integersIn: swiftRange) { return true }
        for h in hits {
            if let r = Range(h.detection.range), r.overlaps(swiftRange) { return true }
        }
        return false
    }

    private static func rangeIsConsumed(_ range: NSRange, excluding: IndexSet, hits: [TimeHit]) -> Bool {
        guard let swiftRange = Range(range) else { return false }
        if excluding.intersects(integersIn: swiftRange) { return true }
        for h in hits {
            if let r = Range(h.detection.range), r.overlaps(swiftRange) { return true }
        }
        return false
    }

    private static func captureGroup(match: NSTextCheckingResult, index: Int, in ns: NSString) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let r = match.range(at: index)
        guard r.location != NSNotFound else { return nil }
        return ns.substring(with: r)
    }

    private static func timeDate(hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private static func nextWeekday(
        named name: String,
        after reference: Date,
        calendar: Calendar,
        preferNextWeek: Bool
    ) -> Date {
        // Calendar.weekday: 1=Sunday … 7=Saturday
        let targetWeekday: Int = {
            switch name.lowercased() {
            case "sunday", "sun":    return 1
            case "monday", "mon":    return 2
            case "tuesday", "tue":   return 3
            case "wednesday", "wed": return 4
            case "thursday", "thu":  return 5
            case "friday", "fri":    return 6
            case "saturday", "sat":  return 7
            default: return calendar.component(.weekday, from: reference)
            }
        }()
        let currentWeekday = calendar.component(.weekday, from: reference)
        var daysAhead = (targetWeekday - currentWeekday + 7) % 7
        if daysAhead == 0 { daysAhead = 7 }         // same-day name → next week
        if preferNextWeek && daysAhead <= 7 {
            // "next monday" always skips to the following week
            daysAhead += 7
        }
        return calendar.date(byAdding: .day, value: daysAhead, to: reference) ?? reference
    }

    // MARK: Cleanup

    private static func cleanTitle(_ raw: String, removing detections: [TaskDetection]) -> String {
        // If nothing was detected, the title is already clean.
        guard !detections.isEmpty else {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Remove in reverse so indices remain valid.
        let ns = NSMutableString(string: raw)
        for det in detections.reversed() {
            ns.replaceCharacters(in: det.range, with: "")
        }

        // Collapse whitespace (including any leading "at " that became orphaned).
        var cleaned = ns as String
        cleaned = cleaned
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Trim trailing filler prepositions if left dangling.
        let fillerTrailing = ["on", "at", "by", "for", "this", "next"]
        for filler in fillerTrailing {
            if cleaned.lowercased().hasSuffix(" \(filler)") {
                cleaned = String(cleaned.dropLast(filler.count + 1))
            }
        }

        // If cleaning stripped everything, fall back to the raw title so we never
        // save an empty task.
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
    }
}

// MARK: - Keyword Tables (extensible)

private enum DateKeywords {
    typealias Resolver = (_ today: Date, _ cal: Calendar) -> Date?

    /// Phrase → resolver. Keep longest phrases first so "this week" is matched
    /// before "week" and "next week" before "week".
    static let phrases: [(String, Resolver)] = [
        ("day after tomorrow", { today, cal in cal.date(byAdding: .day, value: 2, to: today) }),
        ("this weekend",       { today, cal in nextWeekendStart(from: today, cal: cal) }),
        ("next week",          { today, cal in cal.date(byAdding: .day, value: 7, to: today) }),
        ("this week",          { today, _ in today }),
        ("tomorrow",           { today, cal in cal.date(byAdding: .day, value: 1, to: today) }),
        ("tonight",            { today, _ in today }),
        ("today",              { today, _ in today }),
    ]

    static let weekdays = [
        "monday", "tuesday", "wednesday", "thursday",
        "friday", "saturday", "sunday"
    ]

    private static func nextWeekendStart(from today: Date, cal: Calendar) -> Date? {
        // Saturday = 7
        let weekday = cal.component(.weekday, from: today)
        var days = 7 - weekday
        if days < 0 { days += 7 }
        if days == 0 { days = 0 } // already Saturday
        return cal.date(byAdding: .day, value: days, to: today)
    }
}

private enum PriorityKeywords {
    struct Phrase { let text: String; let priority: Priority }
    static let all: [Phrase] = [
        .init(text: "high priority", priority: .high),
        .init(text: "low priority",  priority: .low),
        .init(text: "important",     priority: .high),
        .init(text: "urgent",        priority: .high),
        .init(text: "asap",          priority: .high),
    ]
}

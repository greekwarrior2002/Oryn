import Foundation

struct ReadinessScore {
    let value: Int
    let level: Level
    let insight: String
    let sleepHours: Double
    let stepCount: Int

    enum Level {
        case low, medium, high

        var label: String {
            switch self {
            case .low:    return "Low"
            case .medium: return "Medium"
            case .high:   return "High"
            }
        }
    }

    static let unavailable = ReadinessScore(
        value: 50,
        level: .medium,
        insight: "Connect Health to get personalized scheduling.",
        sleepHours: 0,
        stepCount: 0
    )

    static func compute(sleepHours: Double, stepCount: Int) -> ReadinessScore {
        var base: Int
        switch sleepHours {
        case ..<5:
            base = max(0, Int((sleepHours / 5.0) * 35))
        case 5..<6:
            base = 35 + Int((sleepHours - 5.0) * 20)
        case 6..<7:
            base = 55 + Int((sleepHours - 6.0) * 15)
        case 7...9:
            base = 70 + Int(((sleepHours - 7.0) / 2.0) * 25)
        default:
            base = 85
        }

        let stepsAdjust: Int
        if stepCount > 8000      { stepsAdjust = 5  }
        else if stepCount < 2000 { stepsAdjust = -5 }
        else                     { stepsAdjust = 0  }

        let finalValue = min(100, max(0, base + stepsAdjust))

        let level: Level
        switch finalValue {
        case 0...40:  level = .low
        case 41...69: level = .medium
        default:      level = .high
        }

        let insight: String
        switch level {
        case .low:
            insight = "You slept less than usual — I've lightened today's workload."
        case .medium:
            insight = "Decent rest. Your schedule is balanced for today."
        case .high:
            insight = "Great sleep and activity. I've loaded up today's best work."
        }

        return ReadinessScore(
            value: finalValue,
            level: level,
            insight: insight,
            sleepHours: sleepHours,
            stepCount: stepCount
        )
    }
}

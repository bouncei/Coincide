import Foundation

/// A coarse time-of-day bucket for a zone, used to give each row a glanceable
/// sun/moon indicator ("are they awake over there?").
enum DayPhase {
    case morning   // 5–11
    case day       // 11–17
    case evening   // 17–21
    case night     // 21–5

    /// SF Symbol name representing the phase.
    var symbol: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .day:     return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night:   return "moon.stars.fill"
        }
    }

    var isDaytime: Bool { self != .night }

    static func current(in timeZone: TimeZone, at date: Date) -> DayPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .morning
        case 11..<17: return .day
        case 17..<21: return .evening
        default:      return .night
        }
    }
}

import Foundation

/// Whether times render in 12-hour ("2:30 PM") or 24-hour ("14:30") form.
enum HourFormat: String, Codable, CaseIterable {
    case twelveHour
    case twentyFourHour

    var displayName: String {
        switch self {
        case .twelveHour: return "12-hour"
        case .twentyFourHour: return "24-hour"
        }
    }
}

/// Pure, unit-tested formatting helpers. Formatters are cached per
/// (timezone, format) pair to avoid the cost of repeated construction.
enum TimeFormatting {
    private static var cache: [String: DateFormatter] = [:]

    static func formatter(for timeZone: TimeZone, format: HourFormat) -> DateFormatter {
        let key = "\(timeZone.identifier)|\(format.rawValue)"
        if let cached = cache[key] { return cached }
        let f = DateFormatter()
        f.timeZone = timeZone
        // Use fixed locales so the hour style is deterministic regardless of
        // the host's region settings.
        f.locale = Locale(identifier: format == .twelveHour ? "en_US_POSIX" : "en_GB")
        f.dateFormat = format == .twelveHour ? "h:mm a" : "HH:mm"
        cache[key] = f
        return f
    }

    /// e.g. "2:30 PM" or "14:30".
    static func time(in timeZone: TimeZone, at date: Date, format: HourFormat) -> String {
        formatter(for: timeZone, format: format).string(from: date)
    }

    /// e.g. "GMT-7", "GMT+1", "GMT+5:30".
    static func gmtOffsetLabel(for timeZone: TimeZone, at date: Date = Date()) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let total = abs(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if minutes == 0 {
            return "GMT\(sign)\(hours)"
        }
        return String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }

    /// e.g. "PDT", "WAT", or a "GMT+1"-style fallback.
    static func abbreviation(for timeZone: TimeZone, at date: Date = Date()) -> String {
        timeZone.abbreviation(for: date) ?? gmtOffsetLabel(for: timeZone, at: date)
    }

    /// How `other`'s calendar day relates to `home`'s for the same instant.
    /// Returns nil when they're on the same day (no label needed).
    static func dayOffsetLabel(home: TimeZone, other: TimeZone, at date: Date) -> String? {
        guard let diff = dayDifference(home: home, other: other, at: date), diff != 0 else {
            return nil
        }
        switch diff {
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case let d where d > 1: return "+\(d) days"
        default: return "\(diff) days"
        }
    }

    /// Signed difference in calendar days between `other` and `home` for the
    /// same instant (other - home).
    static func dayDifference(home: TimeZone, other: TimeZone, at date: Date) -> Int? {
        let homeComps = civilComponents(date, in: home)
        let otherComps = civilComponents(date, in: other)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let homeDate = utc.date(from: homeComps),
              let otherDate = utc.date(from: otherComps) else { return nil }
        return utc.dateComponents([.day], from: homeDate, to: otherDate).day
    }

    private static func civilComponents(_ date: Date, in timeZone: TimeZone) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.dateComponents([.year, .month, .day], from: date)
    }
}

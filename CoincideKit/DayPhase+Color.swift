import SwiftUI

/// Shared day/night palette so the popover, dashboard, and widget all read the
/// same colors. Tuned to sit alongside the warm "sunrise" accent.
extension DayPhase {
    /// Color for the small sun/moon glyph next to a time.
    var glyphColor: Color {
        switch self {
        case .morning: return Color(red: 0.98, green: 0.62, blue: 0.20) // amber
        case .day:     return Color(red: 1.00, green: 0.78, blue: 0.25) // warm gold
        case .evening: return Color(red: 0.96, green: 0.45, blue: 0.42) // coral
        case .night:   return Color(red: 0.55, green: 0.60, blue: 0.95) // soft indigo
        }
    }

    /// Fill for one hour cell in a 24-hour day/night band.
    var bandColor: Color {
        switch self {
        case .night:   return Color(red: 0.16, green: 0.19, blue: 0.42).opacity(0.92) // deep navy
        case .morning: return Color(red: 0.98, green: 0.62, blue: 0.30).opacity(0.55) // dawn amber
        case .day:     return Color(red: 1.00, green: 0.80, blue: 0.32).opacity(0.62) // warm day
        case .evening: return Color(red: 0.95, green: 0.45, blue: 0.45).opacity(0.55) // dusk coral
        }
    }
}

import SwiftUI

/// Pure visual model for the onboarding "sky": maps a time-of-day fraction to
/// gradient colors and a sun/moon arc position. No view state — the numeric core
/// (`RGB`, `skyStops`, `celestialArcPosition`) is unit-tested; SwiftUI `Color`
/// helpers are thin wrappers on top.
enum SkyModel {

    // Sun above the horizon between these fractions of the day (06:00–19:00).
    static let sunrise = 6.0 / 24.0
    static let sunset = 19.0 / 24.0

    /// Fraction of the day in `[0, 1)` — 0 = midnight, 0.5 = noon — for a zone.
    static func dayFraction(of date: Date, in timeZone: TimeZone) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        let h: Int = c.hour ?? 0
        let m: Int = c.minute ?? 0
        let s: Int = c.second ?? 0
        let seconds = Double(h * 3600 + m * 60 + s)
        return seconds / 86_400
    }

    /// Whether the sun is above the horizon at this fraction.
    static func isDaytime(_ fraction: Double) -> Bool {
        let f = fraction.truncatingRemainder(dividingBy: 1)
        return f >= sunrise && f < sunset
    }

    /// Sun/moon position on a horizon arc, normalized so x,y ∈ [0, 1]:
    /// x runs left→right across the active window (day or night), y is 1 at the
    /// horizon and 0 at the zenith (screen-space, so smaller y = higher up).
    static func celestialArcPosition(_ fraction: Double) -> CGPoint {
        let f = fraction.truncatingRemainder(dividingBy: 1)
        let t: Double
        if isDaytime(f) {
            t = (f - sunrise) / (sunset - sunrise)
        } else {
            // Night wraps midnight: sunset … (1 + sunrise).
            let wrapped = f < sunrise ? f + 1 : f
            t = (wrapped - sunset) / (1 + sunrise - sunset)
        }
        let x = t
        let y = 1 - sin(max(0, min(1, t)) * .pi) // parabolic arc, peak at midpoint
        return CGPoint(x: x, y: y)
    }

    // MARK: - Gradient

    /// A plain RGB triple so the color math is testable without SwiftUI.
    struct RGB: Equatable {
        var r, g, b: Double
        func lerp(to o: RGB, _ t: Double) -> RGB {
            RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
        }
        var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
    }

    /// Keyframes around the day (fraction, top-of-sky, horizon). Tuned to sit
    /// alongside the warm "sunrise" accent and the app's day/night palette.
    private static let keyframes: [(f: Double, top: RGB, bottom: RGB)] = [
        (0.00, RGB(r: 0.09, g: 0.11, b: 0.28), RGB(r: 0.20, g: 0.19, b: 0.42)), // deep night
        (0.22, RGB(r: 0.24, g: 0.24, b: 0.46), RGB(r: 0.63, g: 0.44, b: 0.52)), // pre-dawn
        (0.27, RGB(r: 0.42, g: 0.44, b: 0.72), RGB(r: 0.99, g: 0.64, b: 0.36)), // sunrise amber
        (0.40, RGB(r: 0.44, g: 0.66, b: 0.94), RGB(r: 0.86, g: 0.90, b: 0.98)), // morning
        (0.50, RGB(r: 0.40, g: 0.64, b: 0.96), RGB(r: 0.82, g: 0.91, b: 1.00)), // bright day
        (0.72, RGB(r: 0.46, g: 0.62, b: 0.92), RGB(r: 1.00, g: 0.82, b: 0.50)), // golden hour
        (0.80, RGB(r: 0.40, g: 0.36, b: 0.62), RGB(r: 0.97, g: 0.53, b: 0.42)), // dusk coral
        (0.88, RGB(r: 0.22, g: 0.22, b: 0.46), RGB(r: 0.55, g: 0.36, b: 0.52)), // twilight
        (1.00, RGB(r: 0.09, g: 0.11, b: 0.28), RGB(r: 0.20, g: 0.19, b: 0.42)), // wrap to night
    ]

    /// Interpolated (top, bottom) sky colors for a fraction of the day.
    static func skyStops(_ fraction: Double) -> (top: RGB, bottom: RGB) {
        let f = fraction.truncatingRemainder(dividingBy: 1)
        var lower = keyframes[0]
        var upper = keyframes[keyframes.count - 1]
        for i in 0..<(keyframes.count - 1) where f >= keyframes[i].f && f <= keyframes[i + 1].f {
            lower = keyframes[i]
            upper = keyframes[i + 1]
            break
        }
        let span = upper.f - lower.f
        let t = span > 0 ? (f - lower.f) / span : 0
        return (lower.top.lerp(to: upper.top, t), lower.bottom.lerp(to: upper.bottom, t))
    }

    /// SwiftUI gradient colors (top → bottom) for a fraction of the day.
    static func skyColors(_ fraction: Double) -> [Color] {
        let s = skyStops(fraction)
        return [s.top.color, s.bottom.color]
    }
}

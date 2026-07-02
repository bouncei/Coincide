import SwiftUI

/// The warm day/night "sky" that gives onboarding its character.
///
/// Two modes:
/// - **Animated** (`fixedFraction == nil`): slowly loops through a full day —
///   dawn → day → dusk → night — used on the hero and finish screens.
/// - **Fixed** (`fixedFraction` set): renders one real moment (e.g. the home
///   zone's *current* sky), used as the banner behind the middle steps.
///
/// All the color/position math lives in the pure, tested `SkyModel`. The loop is
/// a lightweight timer that only runs while the view is on screen and is torn
/// down in `onDisappear`, so the accessory app returns to idle. Reduce Motion
/// pins a single tasteful frame.
struct AnimatedSkyView: View {
    /// When set, renders this fixed fraction of the day and never animates.
    var fixedFraction: Double? = nil
    /// Seconds for one full day loop when animating.
    var loopDuration: Double = 44
    /// Whether to draw the sun/moon on its arc.
    var showsCelestialBody: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0
    @State private var timer: Timer?

    private var fraction: Double { fixedFraction ?? phase }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: SkyModel.skyColors(fraction),
                               startPoint: .top, endPoint: .bottom)
                StarField(opacity: starOpacity(fraction))
                if showsCelestialBody {
                    celestialBody(in: geo.size)
                }
            }
        }
        .onAppear(perform: startIfNeeded)
        .onDisappear(perform: stop)
    }

    // MARK: Sun / moon

    @ViewBuilder
    private func celestialBody(in size: CGSize) -> some View {
        let p = SkyModel.celestialArcPosition(fraction)
        let x = p.x * size.width
        let y = (0.16 + p.y * 0.72) * size.height // keep within frame, horizon low
        let day = SkyModel.isDaytime(fraction)
        ZStack {
            Circle()
                .fill(day ? Color(red: 1.0, green: 0.86, blue: 0.5) : Color(red: 0.9, green: 0.92, blue: 1.0))
                .frame(width: day ? 46 : 34, height: day ? 46 : 34)
                .blur(radius: day ? 22 : 12)
                .opacity(0.75)
            Circle()
                .fill(day
                      ? LinearGradient(colors: [Color(red: 1.0, green: 0.95, blue: 0.78), Color(red: 1.0, green: 0.82, blue: 0.42)],
                                       startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [.white, Color(red: 0.86, green: 0.89, blue: 1.0)],
                                       startPoint: .top, endPoint: .bottom))
                .frame(width: day ? 40 : 26, height: day ? 40 : 26)
                .overlay {
                    if !day { // a couple of soft craters on the moon
                        Circle().fill(.black.opacity(0.06)).frame(width: 7, height: 7).offset(x: -4, y: -3)
                        Circle().fill(.black.opacity(0.05)).frame(width: 5, height: 5).offset(x: 5, y: 4)
                    }
                }
        }
        .position(x: x, y: y)
        .animation(.easeInOut(duration: 0.4), value: day)
    }

    private func starOpacity(_ f: Double) -> Double {
        guard !SkyModel.isDaytime(f) else { return 0 }
        // Fade stars in/out near the sunrise/sunset boundaries.
        let toSunrise = (SkyModel.sunrise - f + 1).truncatingRemainder(dividingBy: 1)
        let sinceSunset = (f - SkyModel.sunset + 1).truncatingRemainder(dividingBy: 1)
        let edge = min(toSunrise, sinceSunset)
        return min(1, edge / 0.05) * 0.85
    }

    // MARK: Animation lifecycle

    private func startIfNeeded() {
        guard fixedFraction == nil, !reduceMotion, timer == nil else {
            if reduceMotion, fixedFraction == nil { phase = 0.30 } // pinned dawn frame
            return
        }
        let fps = 20.0
        let step = 1.0 / (loopDuration * fps)
        let t = Timer(timeInterval: 1.0 / fps, repeats: true) { _ in
            phase = (phase + step).truncatingRemainder(dividingBy: 1)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

/// A quiet field of stars, positioned deterministically so they never flicker
/// between renders. Fades as a whole via `opacity`.
private struct StarField: View {
    var opacity: Double

    // Deterministic unit-space positions + relative sizes.
    private static let stars: [(x: Double, y: Double, s: Double)] = [
        (0.08, 0.14, 1.0), (0.18, 0.30, 0.6), (0.27, 0.10, 0.8), (0.36, 0.24, 0.5),
        (0.44, 0.08, 0.9), (0.52, 0.20, 0.6), (0.61, 0.12, 0.7), (0.70, 0.28, 0.5),
        (0.78, 0.09, 0.9), (0.86, 0.22, 0.6), (0.93, 0.15, 0.8), (0.14, 0.42, 0.5),
        (0.33, 0.40, 0.6), (0.58, 0.38, 0.5), (0.75, 0.44, 0.6), (0.90, 0.36, 0.5),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, star in
                Circle()
                    .fill(.white)
                    .frame(width: 2 * star.s, height: 2 * star.s)
                    .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}

import SwiftUI

/// A warm one-shot burst for the finish screen — particles radiate outward and
/// upward, then fade. Plays once on appear (and on `trigger` change); no
/// retained timer, so nothing runs after the celebration settles. Skipped under
/// Reduce Motion.
struct SunriseParticles: View {
    var count: Int = 30
    /// Bump this to replay the burst.
    var trigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var go = false

    private let palette: [Color] = [
        .accentColor,
        Color(red: 1.0, green: 0.82, blue: 0.42), // gold
        Color(red: 0.96, green: 0.45, blue: 0.42), // coral
        Color(red: 0.55, green: 0.60, blue: 0.95), // indigo
        .white,
    ]

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<count, id: \.self) { i in
                    particle(i)
                }
            }
        }
        .onAppear(perform: fire)
        .onChange(of: trigger) { _, _ in
            go = false
            fire()
        }
        .allowsHitTesting(false)
    }

    private func fire() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 1.5)) { go = true }
    }

    private func particle(_ i: Int) -> some View {
        let angle = Double(i) / Double(count) * 2 * .pi
        let jitter = Double((i * 41) % 70)
        let dist = go ? 110 + CGFloat(jitter) : 0
        let dx = CGFloat(cos(angle)) * dist
        let dy = CGFloat(sin(angle)) * dist - (go ? 50 : 0) // bias upward
        let size = 5 + CGFloat((i * 13) % 5)
        return Circle()
            .fill(palette[i % palette.count])
            .frame(width: size, height: size)
            .scaleEffect(go ? 0.3 : 1)
            .opacity(go ? 0 : 1)
            .offset(x: dx, y: dy)
    }
}

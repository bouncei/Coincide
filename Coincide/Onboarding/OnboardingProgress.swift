import SwiftUI

/// A slim, sunrise-tinted step indicator: a connecting track that fills up to
/// the current step, with a soft glow on the active node.
struct OnboardingProgress: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: i == index ? 22 : 7, height: 7)
                    .shadow(color: i == index ? Color.accentColor.opacity(0.6) : .clear,
                            radius: 4, y: 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: index)
            }
        }
    }
}

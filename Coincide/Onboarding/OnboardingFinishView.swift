import SwiftUI

/// The reward: a warm sunrise send-off with a burst of particles and a live
/// preview of the menu-bar item the user will now see. Full-bleed; owns its CTA.
struct OnboardingFinishView: View {
    let homeID: String
    let referenceID: String?
    let hourFormat: HourFormat
    let now: Date
    let onDone: () -> Void

    @State private var appeared = false

    private var menuBarZoneID: String { referenceID ?? homeID }

    var body: some View {
        ZStack {
            AnimatedSkyView(fixedFraction: 0.27, showsCelestialBody: true) // dawn: a new beginning
                .overlay(Color.black.opacity(0.12))
            SunriseParticles()

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 6) {
                    Text("You're all set")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Your zones are ready. Coincide lives in your menu bar — always a glance away.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                menuBarPreview
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer()

                Button(action: onDone) {
                    Text("Start using Coincide")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: 260)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 36)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) {
                appeared = true
            }
        }
    }

    private var menuBarPreview: some View {
        let tz = TimeZone(identifier: menuBarZoneID) ?? .current
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(SavedZone.flag(for: TimezoneCountries.codeByZone[menuBarZoneID]))
                    .font(.system(size: 13))
                Text(TimeFormatting.time(in: tz, at: now, format: hourFormat))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35)))

            Label("Look for this up here", systemImage: "arrow.up")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

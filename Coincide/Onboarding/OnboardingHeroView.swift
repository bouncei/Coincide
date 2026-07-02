import SwiftUI
import AppKit

/// Step 0: a full-bleed animated sky with the wordmark rising in and a few
/// world-clock chips materializing. Owns its "Get started" CTA.
struct OnboardingHeroView: View {
    let onStart: () -> Void

    @State private var appeared = false

    // Decorative sample chips (a spread of zones) that fade in behind the title.
    private let sampleZones = ["Africa/Lagos", "America/Los_Angeles", "America/New_York", "Europe/London"]

    var body: some View {
        ZStack {
            AnimatedSkyView(loopDuration: 40)
                .overlay(Color.black.opacity(0.10))

            VStack(spacing: 18) {
                Spacer()

                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 84)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Coincide")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Every zone you work with, side by side —\nalways a glance away in your menu bar.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                chips
                    .padding(.top, 4)

                Spacer()

                Button(action: onStart) {
                    Text("Get started")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: 240)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(Array(sampleZones.enumerated()), id: \.offset) { i, id in
                let tz = TimeZone(identifier: id) ?? .current
                HStack(spacing: 5) {
                    Text(SavedZone.flag(for: TimezoneCountries.codeByZone[id]))
                        .font(.system(size: 12))
                    Text(TimeFormatting.time(in: tz, at: Date(), format: .twelveHour))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3 + Double(i) * 0.08), value: appeared)
            }
        }
    }
}

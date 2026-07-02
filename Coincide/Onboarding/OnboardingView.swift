import SwiftUI

/// First-launch flow, redesigned as a cinematic, value-first experience:
/// hero → home zone → add-your-world (with a live preview) → optional calendar
/// → a celebratory finish. Still writes everything in one shot via
/// `ZoneStore.finishOnboarding(...)` at the end.
struct OnboardingView: View {
    @EnvironmentObject var store: ZoneStore
    @EnvironmentObject var clock: MinuteClock
    @EnvironmentObject var calendar: CalendarHub

    private enum Step: Int, CaseIterable { case welcome, home, world, calendar, finish }
    @State private var step: Step = .welcome

    @State private var homeID = TimeZone.current.identifier
    @State private var otherIDs: Set<String> = []
    @State private var hourFormat: HourFormat = .twelveHour

    var body: some View {
        content
            .frame(width: 520, height: 640)
            .transition(.opacity)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            OnboardingHeroView(onStart: { go(.home) })
                .transition(.opacity)
        case .finish:
            OnboardingFinishView(homeID: homeID, referenceID: nil,
                                 hourFormat: hourFormat, now: clock.now,
                                 onDone: finish)
                .transition(.opacity)
        default:
            middleStep
                .transition(.opacity)
        }
    }

    // MARK: Middle steps (home / world / calendar)

    private var middleStep: some View {
        VStack(spacing: 0) {
            banner
            Divider()
            ScrollView {
                stepBody
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)
            Divider()
            controls
        }
    }

    private var banner: some View {
        let fraction = SkyModel.dayFraction(of: clock.now, in: TimeZone(identifier: homeID) ?? .current)
        return ZStack(alignment: .bottomLeading) {
            AnimatedSkyView(fixedFraction: fraction, showsCelestialBody: true)
            VStack {
                HStack {
                    Spacer()
                    OnboardingProgress(count: 3, index: (step.rawValue - 1))
                }
                .padding(14)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(height: 128)
    }

    private var title: String {
        switch step {
        case .home: return "Where's home?"
        case .world: return "Add your world"
        case .calendar: return "See your meetings too"
        default: return ""
        }
    }

    private var subtitle: String {
        switch step {
        case .home: return "We detected this from your Mac — change it if it's off."
        case .world: return "Pick the zones you work with. Watch your day line up."
        case .calendar: return "Optional — bring your meetings into every zone."
        default: return ""
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .home: homeBody
        case .world: worldBody
        case .calendar: OnboardingCalendarStep()
        default: EmptyView()
        }
    }

    // MARK: Home

    private var homeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(SavedZone.flag(for: TimezoneCountries.codeByZone[homeID]))
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(SavedZone.cityName(for: homeID)).font(.system(size: 15, weight: .semibold))
                        Image(systemName: "house.fill").font(.system(size: 9)).foregroundStyle(.tint)
                    }
                    Text("\(SavedZone(tzIdentifier: homeID).countryName ?? homeID)  ·  \(TimeFormatting.gmtOffsetLabel(for: TimeZone(identifier: homeID) ?? .current))")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(TimeFormatting.time(in: TimeZone(identifier: homeID) ?? .current, at: clock.now, format: hourFormat))
                    .font(.system(size: 20, weight: .medium, design: .rounded)).monospacedDigit()
            }
            .padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

            Text("Pick a different home zone").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            ZonePickerView(selection: Binding(
                get: { [homeID] },
                set: { homeID = $0.first ?? homeID }
            ), singleSelect: true)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
        }
    }

    // MARK: World

    private var worldBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiveZonePreviewView(homeID: homeID,
                                otherIDs: Array(otherIDs).sorted(),
                                now: clock.now,
                                hourFormat: hourFormat)

            ZonePickerView(selection: $otherIDs, excluded: [homeID])
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))

            HStack {
                Text("Time format").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $hourFormat) {
                    ForEach(HourFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 180)
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack {
            Button("Back") { back() }
                .buttonStyle(.bordered)
            Spacer()
            Button(step == .calendar ? "Finish" : "Continue") { forward() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    // MARK: Navigation

    private func go(_ s: Step) { withAnimation(.easeInOut(duration: 0.3)) { step = s } }

    private func forward() {
        switch step {
        case .home: go(.world)
        case .world: go(.calendar)
        case .calendar: go(.finish)
        default: break
        }
    }

    private func back() {
        switch step {
        case .home: go(.welcome)
        case .world: go(.home)
        case .calendar: go(.world)
        default: break
        }
    }

    private func finish() {
        // Writing the store flips `didCompleteOnboarding`, so RootWindowView
        // swaps straight to the dashboard — no dismiss needed. Menu-bar zone
        // defaults to home; both it and the format are changeable in Settings.
        store.finishOnboarding(
            homeIdentifier: homeID,
            otherIdentifiers: Array(otherIDs),
            referenceIdentifier: nil,
            hourFormat: hourFormat
        )
    }
}

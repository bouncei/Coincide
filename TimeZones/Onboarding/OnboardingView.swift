import SwiftUI

/// First-launch flow: welcome → confirm home zone → add work zones & pick the
/// menu bar reference. Writes everything to the store in one shot at the end.
struct OnboardingView: View {
    @EnvironmentObject var store: ZoneStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var homeID = TimeZone.current.identifier
    @State private var otherIDs: Set<String> = []
    @State private var referenceID: String?
    @State private var hourFormat: HourFormat = .twelveHour

    var body: some View {
        VStack(spacing: 0) {
            ProgressDots(count: 3, index: step)
                .padding(.top, 18)

            Group {
                switch step {
                case 0: welcome
                case 1: homeStep
                default: zonesStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            controls
        }
        .frame(width: 480, height: 580)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
            Text("Welcome to TimeZones")
                .font(.system(size: 24, weight: .bold))
            Text("Keep your home time and the zones you work with side by side — in your menu bar and as a widget — so you never miscount the hours again.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var homeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("Your home time zone",
                       "We detected this from your Mac. Change it if it's wrong.")
            HStack(spacing: 10) {
                Image(systemName: "house.fill").foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SavedZone.cityName(for: homeID)).font(.system(size: 15, weight: .semibold))
                    Text("\(homeID)  ·  \(TimeFormatting.gmtOffsetLabel(for: TimeZone(identifier: homeID) ?? .current))")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(TimeFormatting.time(in: TimeZone(identifier: homeID) ?? .current, at: Date(), format: hourFormat))
                    .font(.system(size: 20, weight: .medium, design: .rounded)).monospacedDigit()
            }
            .padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

            Text("Pick a different home zone").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            ZonePickerView(selection: Binding(
                get: { [homeID] },
                set: { homeID = $0.first ?? homeID }
            ), singleSelect: true)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var zonesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("Add the zones you work with",
                       "Choose as many as you like — PST, EST, or anywhere else.")
            ZonePickerView(selection: $otherIDs, excluded: [homeID])
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))

            HStack {
                Text("Show in menu bar").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $referenceID) {
                    Text("Home (\(SavedZone.cityName(for: homeID)))").tag(String?.none)
                    ForEach(Array(otherIDs).sorted(), id: \.self) { id in
                        Text(SavedZone.cityName(for: id)).tag(String?.some(id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
            }

            HStack {
                Text("Time format").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $hourFormat) {
                    ForEach(HourFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: Chrome

    private func stepHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 18, weight: .bold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.bordered)
            }
            Spacer()
            Button(step < 2 ? "Continue" : "Done") {
                if step < 2 {
                    step += 1
                } else {
                    finish()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func finish() {
        store.finishOnboarding(
            homeIdentifier: homeID,
            otherIdentifiers: Array(otherIDs),
            referenceIdentifier: referenceID,
            hourFormat: hourFormat
        )
        dismiss()
    }
}

/// Small page indicator for the onboarding steps.
private struct ProgressDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: 7, height: 7)
            }
        }
    }
}

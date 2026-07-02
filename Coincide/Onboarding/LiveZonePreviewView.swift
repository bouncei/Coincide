import SwiftUI

/// The "aha" moment: a shared day laid out in the *home* zone's hours, with one
/// day/night band per zone. Because the axis is shared, you can read straight
/// down a column — "when it's 9am for me, it's the middle of the night for
/// them" — and a live "now" line ties it to the real moment. Rows spring in as
/// zones are added.
struct LiveZonePreviewView: View {
    let homeID: String
    let otherIDs: [String]
    let now: Date
    let hourFormat: HourFormat

    private var rows: [String] { [homeID] + otherIDs.filter { $0 != homeID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your day, side by side")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimeFormatting.gmtOffsetLabel(for: TimeZone(identifier: homeID) ?? .current)
                     .replacingOccurrences(of: "GMT", with: "Home "))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            ZStack(alignment: .topLeading) {
                VStack(spacing: 6) {
                    ForEach(rows, id: \.self) { id in
                        row(for: id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.96).combined(with: .opacity),
                                removal: .opacity))
                    }
                }
                nowLine
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rows)

            if otherIDs.isEmpty {
                Text("Add a zone to see how your days line up.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Row

    private func row(for id: String) -> some View {
        let tz = TimeZone(identifier: id) ?? .current
        let isHome = id == homeID
        return HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(SavedZone.flag(for: TimezoneCountries.codeByZone[id]))
                    .font(.system(size: 15))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 3) {
                        Text(SavedZone.cityName(for: id))
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        if isHome {
                            Image(systemName: "house.fill")
                                .font(.system(size: 7)).foregroundStyle(.tint)
                        }
                    }
                    Text(TimeFormatting.time(in: tz, at: now, format: hourFormat))
                        .font(.system(size: 10, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, alignment: .leading)

            band(for: tz)
                .frame(height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    /// 24 cells across the shared home-zone day, each colored by this zone's
    /// local phase at that home-hour.
    private func band(for tz: TimeZone) -> some View {
        var homeCal = Calendar(identifier: .gregorian)
        homeCal.timeZone = TimeZone(identifier: homeID) ?? .current
        let base = homeCal.startOfDay(for: now)
        return GeometryReader { geo in
            let w = geo.size.width / 24
            HStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { h in
                    let date = base.addingTimeInterval(Double(h) * 3600)
                    let phase = DayPhase.current(in: tz, at: date)
                    Rectangle()
                        .fill(phase.bandColor)
                        .frame(width: w)
                }
            }
        }
    }

    // MARK: Now line

    private var nowLine: some View {
        GeometryReader { geo in
            let labelW: CGFloat = 96 + 10 // label column + spacing
            let trackW = geo.size.width - labelW
            let f = SkyModel.dayFraction(of: now, in: TimeZone(identifier: homeID) ?? .current)
            Rectangle()
                .fill(.white.opacity(0.9))
                .frame(width: 1.5)
                .shadow(color: .black.opacity(0.25), radius: 1)
                .position(x: labelW + trackW * f, y: geo.size.height / 2)
        }
        .allowsHitTesting(false)
    }
}

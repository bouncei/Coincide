import SwiftUI

/// One zone row inside the menu bar popover: flag avatar, name + country,
/// large current time, a day/night glyph, and a day-offset tag.
struct ZoneRowView: View {
    @EnvironmentObject var store: ZoneStore
    let zone: SavedZone
    let now: Date

    private var isHome: Bool { store.isHome(zone) }
    private var isReference: Bool { store.isReference(zone) }
    private var phase: DayPhase { DayPhase.current(in: zone.timeZone, at: now) }

    private var dayLabel: String? {
        TimeFormatting.dayOffsetLabel(home: store.homeTimeZone, other: zone.timeZone, at: now)
    }

    var body: some View {
        HStack(spacing: 11) {
            flagAvatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(zone.displayName)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    if isHome {
                        Image(systemName: "house.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.tint)
                    }
                    if isReference {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeFormatting.time(in: zone.timeZone, at: now, format: store.hourFormat))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    Image(systemName: phase.symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(phaseColor)
                        .symbolRenderingMode(.hierarchical)
                    if let dayLabel {
                        Text(dayLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(dayLabel == "Yesterday" ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isHome ? Color.accentColor.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Show in Menu Bar") { store.setReference(zone) }.disabled(isReference)
            Button("Set as Home") { store.setHome(zone) }.disabled(isHome)
            Divider()
            Button("Remove", role: .destructive) { store.removeZone(zone) }.disabled(isHome)
        }
    }

    private var flagAvatar: some View {
        Text(zone.flag)
            .font(.system(size: 20))
            .frame(width: 34, height: 34)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            )
    }

    /// "Los Angeles, United States · GMT-7" (city omitted when it equals the
    /// country, e.g. "Singapore · GMT+8").
    private var subtitle: String {
        let offset = TimeFormatting.gmtOffsetLabel(for: zone.timeZone, at: now)
        if let country = zone.countryName, country != zone.cityName {
            return "\(zone.cityName), \(country) · \(offset)"
        }
        return "\(zone.cityName) · \(offset)"
    }

    private var phaseColor: Color {
        switch phase {
        case .morning: return .orange
        case .day:     return .yellow
        case .evening: return .pink
        case .night:   return .indigo
        }
    }
}

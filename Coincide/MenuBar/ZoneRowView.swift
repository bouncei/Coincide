import SwiftUI

/// One zone row inside the menu bar popover: flag, name + country, large
/// current time, a day/night glyph, and a day-offset tag. Flat & airy — no
/// row background; home is marked by an accent house glyph only.
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
        HStack(spacing: Theme.avatarGap) {
            Text(zone.flag)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(zone.displayName)
                        .font(.system(size: Theme.FontSize.rowName, weight: .semibold))
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
                    .font(.system(size: Theme.FontSize.meta))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeFormatting.time(in: zone.timeZone, at: now, format: store.hourFormat))
                    .font(.system(size: Theme.FontSize.time, weight: .medium, design: .rounded))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    Image(systemName: phase.symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(phase.glyphColor)
                        .symbolRenderingMode(.hierarchical)
                    if let dayLabel {
                        Text(dayLabel)
                            .font(.system(size: Theme.FontSize.tag, weight: .semibold))
                            .foregroundStyle(dayLabel == "Yesterday" ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                    }
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, Theme.rowVPad)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Show in Menu Bar") { store.setReference(zone) }.disabled(isReference)
            Button("Set as Home") { store.setHome(zone) }.disabled(isHome)
            Divider()
            Button("Remove", role: .destructive) { store.removeZone(zone) }.disabled(isHome)
        }
    }

    /// "Los Angeles, United States · GMT-7" (city only when it equals country).
    private var subtitle: String {
        let offset = TimeFormatting.gmtOffsetLabel(for: zone.timeZone, at: now)
        if let country = zone.countryName, country != zone.cityName {
            return "\(zone.cityName), \(country) · \(offset)"
        }
        return "\(zone.cityName) · \(offset)"
    }
}

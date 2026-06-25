import SwiftUI

/// One zone row inside the menu bar popover.
struct ZoneRowView: View {
    @EnvironmentObject var store: ZoneStore
    let zone: SavedZone
    let now: Date

    private var isHome: Bool { store.isHome(zone) }
    private var isReference: Bool { store.isReference(zone) }

    private var dayLabel: String? {
        TimeFormatting.dayOffsetLabel(home: store.homeTimeZone, other: zone.timeZone, at: now)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(zone.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if isHome { tag("HOME") }
                    if isReference { Image(systemName: "menubar.rectangle").font(.system(size: 9)).foregroundStyle(.tint) }
                }
                Text("\(zone.cityName)  ·  \(TimeFormatting.gmtOffsetLabel(for: zone.timeZone, at: now))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(TimeFormatting.time(in: zone.timeZone, at: now, format: store.hourFormat))
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .monospacedDigit()
                if let dayLabel {
                    Text(dayLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(dayLabel == "Yesterday" ? .secondary : Color.orange)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Show in Menu Bar") { store.setReference(zone) }
                .disabled(isReference)
            Button("Set as Home") { store.setHome(zone) }
                .disabled(isHome)
            Divider()
            Button("Remove", role: .destructive) { store.removeZone(zone) }
                .disabled(isHome)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: Capsule())
    }
}

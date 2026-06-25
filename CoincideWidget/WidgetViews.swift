import WidgetKit
import SwiftUI

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ZoneEntry

    var body: some View {
        if entry.state.zones.isEmpty {
            EmptyWidgetView()
        } else if family == .systemSmall {
            SmallWidgetView(entry: entry)
        } else {
            MediumWidgetView(entry: entry)
        }
    }
}

/// Small: the reference zone, large.
private struct SmallWidgetView: View {
    let entry: ZoneEntry

    private var zone: SavedZone? { entry.state.referenceZone }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let zone {
                HStack(spacing: 5) {
                    Text(zone.flag).font(.system(size: 18))
                    Text(zone.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                Text(zone.countryName ?? zone.cityName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(TimeFormatting.time(in: zone.timeZone, at: entry.date, format: entry.state.hourFormat))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(TimeFormatting.gmtOffsetLabel(for: zone.timeZone, at: entry.date))
                    if let day = TimeFormatting.dayOffsetLabel(home: entry.state.homeTimeZone, other: zone.timeZone, at: entry.date) {
                        Text("· \(day)").foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Medium: up to four zones in two columns.
private struct MediumWidgetView: View {
    let entry: ZoneEntry

    private var zones: [SavedZone] { Array(entry.state.displayZones.prefix(4)) }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(zones) { zone in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(zone.flag).font(.system(size: 13))
                        Text(zone.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        if entry.state.homeZone?.id == zone.id {
                            Image(systemName: "house.fill").font(.system(size: 8)).foregroundStyle(.tint)
                        }
                    }
                    Text(TimeFormatting.time(in: zone.timeZone, at: entry.date, format: entry.state.hourFormat))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Text(TimeFormatting.gmtOffsetLabel(for: zone.timeZone, at: entry.date))
                        if let day = TimeFormatting.dayOffsetLabel(home: entry.state.homeTimeZone, other: zone.timeZone, at: entry.date) {
                            Text("· \(day)").foregroundStyle(.orange)
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "globe").font(.system(size: 22)).foregroundStyle(.tertiary)
            Text("Open Coincide to add zones")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

/// One "Up next" row: title + home-zone start time + calendar-color dot;
/// tapping expands the event's time across every tracked zone.
struct EventRowView: View {
    @EnvironmentObject var store: ZoneStore
    let event: CalendarEventInfo
    let now: Date

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(Color(hex: event.calendarColorHex) ?? .accentColor)
                        .frame(width: 8, height: 8)
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(TimeFormatting.time(in: store.homeTimeZone, at: event.start, format: store.hourFormat))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                let lines = CalendarLogic.zoneLines(for: event, zones: store.displayZones, format: store.hourFormat)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(lines, id: \.self) { line in
                        HStack(spacing: 6) {
                            Text(line.flag).font(.system(size: 12))
                            Text(line.city).font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(line.time).font(.system(size: 11, weight: .medium)).monospacedDigit()
                            Image(systemName: line.phaseSymbol)
                                .font(.system(size: 8))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 17)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 8)
    }
}

extension Color {
    /// Hex like "#RRGGBB" → Color; nil on bad input.
    init?(hex: String?) {
        guard let hex, hex.hasPrefix("#"), hex.count == 7,
              let v = Int(hex.dropFirst(), radix: 16) else { return nil }
        self = Color(.sRGB,
                     red: Double((v >> 16) & 0xFF) / 255,
                     green: Double((v >> 8) & 0xFF) / 255,
                     blue: Double(v & 0xFF) / 255)
    }
}

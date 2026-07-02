import SwiftUI
import AppKit

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
                    if let url = event.url {
                        EventLinkButton(url: url, isMeeting: CalendarLogic.isMeetingLink(url))
                    }
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
        .padding(.vertical, 11)
    }
}

/// A compact, tinted capsule action: "Join" (video icon) for a live meeting,
/// "Open" (arrow) for an event page. Highlights on hover, dips on press.
private struct EventLinkButton: View {
    let url: URL
    let isMeeting: Bool
    @State private var hovering = false

    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            HStack(spacing: 3) {
                Image(systemName: isMeeting ? "video.fill" : "arrow.up.forward")
                    .font(.system(size: 8.5, weight: .bold))
                Text(isMeeting ? "Join" : "Open")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                Capsule().fill(Color.accentColor.opacity(hovering ? 0.22 : 0.13))
            )
            .overlay(
                Capsule().strokeBorder(Color.accentColor.opacity(hovering ? 0.45 : 0.28), lineWidth: 0.75)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .help(isMeeting ? "Join meeting" : "Open event")
    }
}

/// Subtle scale-down on press for a tactile feel.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
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

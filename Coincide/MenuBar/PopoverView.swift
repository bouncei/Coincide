import SwiftUI
import AppKit

/// Measures the popover's scroll content height so the popover can size itself
/// to fit (up to a cap) rather than reserving a fixed height.
private struct PopoverContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// The dropdown shown when the menu bar item is clicked.
struct PopoverView: View {
    @EnvironmentObject var store: ZoneStore
    @EnvironmentObject var clock: MinuteClock
    @EnvironmentObject var calendar: CalendarHub
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if calendar.isActive {
                        upNextContent
                        Divider()
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                    }
                    if store.zones.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.displayZones) { zone in
                            ZoneRowView(zone: zone, now: clock.now)
                                .environmentObject(store)
                        }
                    }
                }
                .padding(.vertical, 6)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: PopoverContentHeight.self, value: geo.size.height)
                })
            }
            // Grow to fit the content (so the zones are visible at a glance),
            // up to a tall cap; only then does it scroll.
            .frame(height: min(contentHeight, 470))
            .onPreferenceChange(PopoverContentHeight.self) { contentHeight = $0 }

            Divider()
            footer
        }
        .frame(width: Theme.popoverWidth)
    }

    /// Opens the settings/onboarding window and brings it to the front (needed
    /// for a menu-bar / accessory app, which otherwise opens windows behind
    /// whatever is focused).
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.main)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text("Coincide")
                    .font(.system(size: 13, weight: .bold))
                if let home = store.homeZone {
                    Text(homeDateLine(home))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                openMainWindow()
            } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(.borderless)
            .help("Open Coincide")
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// e.g. "Today in Lagos · Mon 22 Jun".
    private func homeDateLine(_ home: SavedZone) -> String {
        let df = DateFormatter()
        df.timeZone = home.timeZone
        df.locale = .current
        df.dateFormat = "EEE d MMM"
        return "Today in \(home.cityName) · \(df.string(from: clock.now))"
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var upNextContent: some View {
        let groups = groupedUpcoming
        if groups.isEmpty {
            HStack {
                Text("UP NEXT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("No upcoming events")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(groups, id: \.label) { group in
                    if !group.label.isEmpty || group.hint != nil {
                        HStack(spacing: 6) {
                            if !group.label.isEmpty {
                                Text(group.label.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            if let hint = group.hint {
                                Text(hint)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.tint)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Theme.gutter)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    ForEach(group.events) { event in
                        EventRowView(event: event, now: clock.now)
                            .environmentObject(store)
                    }
                }
            }
        }
    }

    /// Upcoming events grouped by day relative to the home zone (Today /
    /// Tomorrow / weekday), preserving start order within each day.
    private var groupedUpcoming: [(label: String, hint: String?, events: [CalendarEventInfo])] {
        let up = CalendarLogic.upcoming(in: calendar.events, now: clock.now)
        guard !up.isEmpty else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = store.homeTimeZone
        let today = cal.startOfDay(for: clock.now)
        let df = DateFormatter()
        df.timeZone = store.homeTimeZone
        df.locale = .current
        df.dateFormat = "EEE d MMM"

        var order: [Int] = []
        var byDay: [Int: [CalendarEventInfo]] = [:]
        for event in up {
            let day = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: event.start)).day ?? 0
            guard day <= 1 else { continue }   // Today and Tomorrow only
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(event)
        }
        return order.map { day in
            let label: String
            switch day {
            case 0: label = ""          // today's events sit at the top, no header
            case 1: label = "Tomorrow"
            default: label = df.string(from: cal.date(byAdding: .day, value: day, to: today) ?? clock.now)
            }
            var hint: String?
            if day == 0, let first = byDay[day]?.first {
                let mins = CalendarLogic.minutesUntilStart(first, now: clock.now)
                if mins >= 0 && mins <= 60 { hint = "starts in \(mins)m" }
            }
            return (label, hint, byDay[day] ?? [])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text("No zones yet")
                .font(.system(size: 13, weight: .semibold))
            Text("Add the timezones you work with to compare them at a glance.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Set Up") { openMainWindow() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
}

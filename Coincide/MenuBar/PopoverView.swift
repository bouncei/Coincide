import SwiftUI
import AppKit

/// The dropdown shown when the menu bar item is clicked.
struct PopoverView: View {
    @EnvironmentObject var store: ZoneStore
    @EnvironmentObject var clock: MinuteClock
    @EnvironmentObject var calendar: CalendarService
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if calendar.isActive {
                upNextSection
                Divider()
            }

            if store.zones.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.displayZones) { zone in
                            ZoneRowView(zone: zone, now: clock.now)
                                .environmentObject(store)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 380)
            }

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
    private var upNextSection: some View {
        let up = CalendarLogic.upcoming(in: calendar.events, now: clock.now)
        VStack(alignment: .leading, spacing: 0) {
            Text("Up next")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
            if up.isEmpty {
                Text("No meetings today")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 8)
            } else {
                ForEach(up.prefix(3)) { event in
                    EventRowView(event: event, now: clock.now)
                        .environmentObject(store)
                }
            }
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

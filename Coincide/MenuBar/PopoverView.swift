import SwiftUI
import AppKit

/// The dropdown shown when the menu bar item is clicked.
struct PopoverView: View {
    @EnvironmentObject var store: ZoneStore
    @EnvironmentObject var clock: MinuteClock
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

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
            Image(systemName: "globe")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
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
            Text("Updated \(TimeFormatting.time(in: .current, at: clock.now, format: store.hourFormat))")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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

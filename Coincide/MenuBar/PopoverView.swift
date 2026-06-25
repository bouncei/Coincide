import SwiftUI
import AppKit

/// The dropdown shown when the menu bar item is clicked.
struct PopoverView: View {
    @EnvironmentObject var store: ZoneStore
    @EnvironmentObject var clock: MinuteClock
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.zones.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.displayZones.enumerated()), id: \.element.id) { index, zone in
                            if index > 0 { Divider().padding(.leading, 14) }
                            ZoneRowView(zone: zone, now: clock.now)
                                .environmentObject(store)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }

            Divider()
            footer
        }
        .frame(width: 300)
    }

    /// Opens the settings/onboarding window and brings it to the front (needed
    /// for a menu-bar / accessory app, which otherwise opens windows behind
    /// whatever is focused).
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.main)
    }

    private var header: some View {
        HStack {
            Text("Coincide")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                openMainWindow()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

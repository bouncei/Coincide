import SwiftUI

/// The dropdown shown when the menu bar item is clicked.
struct PopoverView: View {
    @EnvironmentObject var store: ZoneStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.zones.isEmpty {
                emptyState
            } else {
                TimelineView(.everyMinute) { context in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.displayZones.enumerated()), id: \.element.id) { index, zone in
                                if index > 0 { Divider().padding(.leading, 14) }
                                ZoneRowView(zone: zone, now: context.date)
                                    .environmentObject(store)
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                }
            }

            Divider()
            footer
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("Coincide")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                openWindow(id: WindowID.main)
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
            TimelineView(.everyMinute) { context in
                Text("Updated \(TimeFormatting.time(in: .current, at: context.date, format: store.hourFormat))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
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
            Button("Set Up") { openWindow(id: WindowID.main) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
}

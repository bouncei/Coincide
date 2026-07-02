import SwiftUI

/// Optional step: invite the user to connect a calendar so meetings show up in
/// their zones. Nothing is required — the container's "Continue" doubles as
/// skip. Permission/OAuth fires only when a button is tapped, reusing the same
/// calls as Settings.
struct OnboardingCalendarStep: View {
    @EnvironmentObject var calendar: CalendarHub
    @State private var connectingGoogle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tint)
                Text("See your meetings, everywhere")
                    .font(.system(size: 20, weight: .bold))
                Text("Coincide can show your upcoming events in every zone, so you always know what time a meeting really is. Read-only — your events never leave your Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                googleRow
                Divider()
                appleRow
            }
            .padding(14)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))

            Text("Optional — you can connect these anytime in Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Google

    @ViewBuilder
    private var googleRow: some View {
        HStack(spacing: 10) {
            connectIcon("g.circle.fill")
            VStack(alignment: .leading, spacing: 1) {
                Text("Google Calendar").font(.system(size: 13, weight: .medium))
                switch calendar.google.auth.state {
                case .connected(let email):
                    Text(email).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                case .needsReauth:
                    Text("Reconnect needed").font(.system(size: 11)).foregroundStyle(.secondary)
                case .notConnected:
                    Text("Events from your Google account").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            switch calendar.google.auth.state {
            case .connected:
                connectedBadge
            case .needsReauth, .notConnected:
                Button {
                    connectingGoogle = true
                    Task { await calendar.google.connect(); connectingGoogle = false }
                } label: {
                    if connectingGoogle {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(connectingGoogle)
            }
        }
    }

    // MARK: Apple

    @ViewBuilder
    private var appleRow: some View {
        HStack(spacing: 10) {
            connectIcon("calendar")
            VStack(alignment: .leading, spacing: 1) {
                Text("macOS Calendar").font(.system(size: 13, weight: .medium))
                if calendar.eventKit.isEnabled, calendar.eventKit.access == .denied {
                    Text("Permission denied — open System Settings")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Text("Events already on your Mac").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if calendar.eventKit.isEnabled, calendar.eventKit.access != .denied {
                connectedBadge
            } else if calendar.eventKit.isEnabled, calendar.eventKit.access == .denied {
                Button("Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            } else {
                Button("Enable") { calendar.eventKit.isEnabled = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    // MARK: Bits

    private func connectIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18))
            .foregroundStyle(.secondary)
            .frame(width: 24)
    }

    private var connectedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Connected").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
    }
}

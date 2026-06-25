import SwiftUI

enum WindowID {
    static let main = "main"
}

@main
struct CoincideApp: App {
    @StateObject private var store = ZoneStore()
    @StateObject private var clock = MinuteClock()
    @StateObject private var presence = WindowPresenceModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
                .environmentObject(clock)
        } label: {
            MenuBarLabelView(store: store, clock: clock)
        }
        .menuBarExtraStyle(.window)

        // Main window: onboarding on first launch, then the dashboard.
        Window("Coincide", id: WindowID.main) {
            RootWindowView()
                .environmentObject(store)
                .environmentObject(clock)
                .tracksWindowPresence(presence)
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)

        // Standard Preferences window (⌘,).
        Settings {
            SettingsView()
                .environmentObject(store)
                .tracksWindowPresence(presence)
        }
    }
}

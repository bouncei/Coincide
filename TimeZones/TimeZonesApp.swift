import SwiftUI

enum WindowID {
    static let main = "main"
}

@main
struct TimeZonesApp: App {
    @StateObject private var store = ZoneStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.window)

        // Single window reused for onboarding (first launch) and settings.
        Window("TimeZones", id: WindowID.main) {
            RootWindowView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

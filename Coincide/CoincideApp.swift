import SwiftUI

enum WindowID {
    static let main = "main"
}

@main
struct CoincideApp: App {
    @StateObject private var store = ZoneStore()
    @StateObject private var clock = MinuteClock()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
                .environmentObject(clock)
        } label: {
            MenuBarLabelView(store: store, clock: clock)
        }
        .menuBarExtraStyle(.window)

        // Single window reused for onboarding (first launch) and settings.
        Window("Coincide", id: WindowID.main) {
            RootWindowView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

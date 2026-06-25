import SwiftUI

enum WindowID {
    static let main = "main"
}

@main
struct CoincideApp: App {
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
        Window("Coincide", id: WindowID.main) {
            RootWindowView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

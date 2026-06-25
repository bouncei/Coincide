import SwiftUI
import AppKit

/// Gives Coincide a Dock icon only while one of its real windows (the main
/// dashboard / onboarding window or Preferences) is open. At rest the app is a
/// menu-bar-only accessory; opening a window flips it to a regular app (Dock +
/// ⌘-Tab), and closing the last window flips it back.
@MainActor
final class WindowPresenceModel: ObservableObject {
    private var openWindows = 0

    func windowAppeared() {
        openWindows += 1
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDisappeared() {
        openWindows = max(0, openWindows - 1)
        if openWindows == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

extension View {
    /// Counts this view's host window toward the app's Dock presence.
    func tracksWindowPresence(_ presence: WindowPresenceModel) -> some View {
        onAppear { presence.windowAppeared() }
            .onDisappear { presence.windowDisappeared() }
    }
}

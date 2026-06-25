import SwiftUI

/// The window's content: onboarding until it's complete, settings afterward.
struct RootWindowView: View {
    @EnvironmentObject var store: ZoneStore

    var body: some View {
        if store.didCompleteOnboarding {
            SettingsView()
        } else {
            OnboardingView()
        }
    }
}

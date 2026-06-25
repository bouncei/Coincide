import SwiftUI

/// The main window's content: onboarding until setup is complete, then the
/// full timezone dashboard.
struct RootWindowView: View {
    @EnvironmentObject var store: ZoneStore

    var body: some View {
        if store.didCompleteOnboarding {
            MainDashboardView()
        } else {
            OnboardingView()
        }
    }
}

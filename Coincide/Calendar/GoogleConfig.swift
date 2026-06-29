import Foundation

/// OAuth client configuration. Replace the placeholders with your Google Cloud
/// OAuth client (iOS/installed-app type — no secret). Forkers override these.
enum GoogleConfig {
    static let clientID = "REPLACE_WITH_CLIENT_ID.apps.googleusercontent.com"
    /// The reverse-client-id scheme; must match the Info.plist CFBundleURLSchemes entry.
    static let redirectScheme = "com.googleusercontent.apps.REPLACE_WITH_CLIENT_ID"
    static var redirectURI: String { "\(redirectScheme):/oauth2redirect" }
    static let scope = "https://www.googleapis.com/auth/calendar.events.readonly"

    static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
}

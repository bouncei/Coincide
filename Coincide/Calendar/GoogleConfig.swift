import Foundation

/// OAuth client configuration. Replace the placeholders with your Google Cloud
/// OAuth client (iOS/installed-app type — no secret). Forkers override these.
enum GoogleConfig {
    static let clientID = "389071915754-2efnf1oeo31eok0ev199ilggvns6c8mc.apps.googleusercontent.com"
    /// The reverse-client-id scheme; must match the Info.plist CFBundleURLSchemes entry.
    static let redirectScheme = "com.googleusercontent.apps.389071915754-2efnf1oeo31eok0ev199ilggvns6c8mc"
    static var redirectURI: String { "\(redirectScheme):/oauth2redirect" }
    static let scope = "https://www.googleapis.com/auth/calendar.readonly"

    static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
}

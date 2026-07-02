import Foundation
import CryptoKit

/// Pure OAuth/PKCE helpers — no network, no Keychain.
enum GoogleAuthLogic {
    /// True if there's no token or it expires within `skew` seconds.
    static func needsRefresh(expiry: Date?, now: Date, skew: TimeInterval = 60) -> Bool {
        guard let expiry else { return true }
        return now.addingTimeInterval(skew) >= expiry
    }

    /// PKCE S256 challenge: base64url(SHA256(verifier)).
    static func pkceChallenge(verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

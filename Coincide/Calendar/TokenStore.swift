import Foundation
import Security

struct GoogleTokens: Codable {
    var refreshToken: String
    var accessToken: String?
    var expiry: Date?
    var email: String?
}

protocol TokenStore {
    func load() -> GoogleTokens?
    func save(_ tokens: GoogleTokens)
    func clear()
}

/// Persists the Google tokens as a JSON blob in the login Keychain.
final class KeychainTokenStore: TokenStore {
    private let service = "dev.bouncei.Coincide.google"
    private let account = "tokens"

    func load() -> GoogleTokens? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(GoogleTokens.self, from: data)
    }

    func save(_ tokens: GoogleTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let query = baseQuery()
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}

/// In-memory store for unit tests / previews.
final class InMemoryTokenStore: TokenStore {
    private var tokens: GoogleTokens?
    func load() -> GoogleTokens? { tokens }
    func save(_ tokens: GoogleTokens) { self.tokens = tokens }
    func clear() { tokens = nil }
}

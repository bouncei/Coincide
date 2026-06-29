import Foundation
import AuthenticationServices

@MainActor
final class GoogleAuth: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    enum State: Equatable {
        case notConnected
        case connected(String)   // email (or "Google")
        case needsReauth
    }
    enum AuthError: Error { case cancelled, badResponse, refreshFailed }

    @Published private(set) var state: State = .notConnected

    private let store: TokenStore
    private var session: ASWebAuthenticationSession?

    init(store: TokenStore = KeychainTokenStore()) {
        self.store = store
        super.init()
        if let t = store.load() {
            state = .connected(t.email ?? "Google")
        }
    }

    var isConnected: Bool { if case .connected = state { return true }; return false }

    // MARK: Connect (interactive)

    func connect() async {
        let verifier = Self.randomString(64)
        let challenge = GoogleAuthLogic.pkceChallenge(verifier: verifier)
        let stateParam = Self.randomString(24)
        var comps = URLComponents(string: GoogleConfig.authEndpoint)!
        comps.queryItems = [
            .init(name: "client_id", value: GoogleConfig.clientID),
            .init(name: "redirect_uri", value: GoogleConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: GoogleConfig.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: stateParam),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent")
        ]
        guard let authURL = comps.url else { return }

        do {
            let callback = try await present(authURL: authURL)
            guard let items = URLComponents(string: callback.absoluteString)?.queryItems,
                  items.first(where: { $0.name == "state" })?.value == stateParam,
                  let code = items.first(where: { $0.name == "code" })?.value
            else { throw AuthError.badResponse }
            try await exchange(code: code, verifier: verifier)
        } catch {
            // Cancelled or failed — leave prior state untouched on cancel.
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin,
               !isConnected {
                state = .notConnected
            }
        }
    }

    private func present(authURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(
                url: authURL, callbackURLScheme: GoogleConfig.redirectScheme
            ) { url, err in
                if let url { cont.resume(returning: url) }
                else { cont.resume(throwing: err ?? AuthError.cancelled) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            self.session = s
            s.start()
        }
    }

    // MARK: Token exchange + refresh

    private func exchange(code: String, verifier: String) async throws {
        let body = [
            "client_id": GoogleConfig.clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": GoogleConfig.redirectURI,
            "grant_type": "authorization_code"
        ]
        let json = try await postToken(body)
        guard let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let expiresIn = json["expires_in"] as? Double else { throw AuthError.badResponse }
        let email = Self.email(fromIDToken: json["id_token"] as? String)
        let tokens = GoogleTokens(refreshToken: refresh, accessToken: access,
                                  expiry: Date().addingTimeInterval(expiresIn), email: email)
        store.save(tokens)
        state = .connected(email ?? "Google")
    }

    func validAccessToken() async throws -> String {
        guard var tokens = store.load() else { state = .notConnected; throw AuthError.refreshFailed }
        if !GoogleAuthLogic.needsRefresh(expiry: tokens.expiry, now: Date()),
           let access = tokens.accessToken { return access }
        // refresh
        let body = [
            "client_id": GoogleConfig.clientID,
            "refresh_token": tokens.refreshToken,
            "grant_type": "refresh_token"
        ]
        do {
            let json = try await postToken(body)
            guard let access = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Double else { throw AuthError.refreshFailed }
            tokens.accessToken = access
            tokens.expiry = Date().addingTimeInterval(expiresIn)
            store.save(tokens)
            return access
        } catch {
            state = .needsReauth
            throw AuthError.refreshFailed
        }
    }

    func disconnect() {
        store.clear()
        state = .notConnected
    }

    // MARK: Helpers

    private func postToken(_ body: [String: String]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: GoogleConfig.tokenEndpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&").data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw AuthError.badResponse }
        return json
    }

    private static func formEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    private static func randomString(_ length: Int) -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars.randomElement(using: &rng)! })
    }

    /// Decode the email claim from a JWT id_token without verification (display only).
    private static func email(fromIDToken token: String?) -> String? {
        guard let parts = token?.split(separator: "."), parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["email"] as? String
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // AuthenticationServices calls this on the main thread. Use
        // MainActor.assumeIsolated rather than DispatchQueue.main.sync, which
        // would deadlock when this is already running on the main thread.
        MainActor.assumeIsolated {
            NSApplication.shared.windows.first ?? ASPresentationAnchor()
        }
    }
}

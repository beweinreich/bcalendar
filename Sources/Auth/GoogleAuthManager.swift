import Foundation
import AppKit

final class GoogleAuthManager {
    static let shared = GoogleAuthManager()

    private var clientId: String = ""
    private var clientSecret: String = ""
    private let redirectURI = "bcalendar://oauth/callback"
    private let scope = "https://www.googleapis.com/auth/calendar"
    private let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenURL = "https://oauth2.googleapis.com/token"
    private let userinfoURL = "https://www.googleapis.com/oauth2/v2/userinfo"

    private var pendingContinuation: CheckedContinuation<URL, Error>?

    init() {
        loadSecrets()
        NotificationCenter.default.addObserver(self, selector: #selector(handleCallback(_:)),
                                                name: .oauthCallback, object: nil)
    }

    private func loadSecrets() {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) else {
            if let envId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"],
               let envSecret = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] {
                clientId = envId
                clientSecret = envSecret
            }
            return
        }
        clientId = dict["GOOGLE_CLIENT_ID"] as? String ?? ""
        clientSecret = dict["GOOGLE_CLIENT_SECRET"] as? String ?? ""
    }

    var isConfigured: Bool { !clientId.isEmpty && !clientSecret.isEmpty }

    func authenticate() async throws -> (account: Account, token: OAuthToken) {
        guard isConfigured else { throw AuthError.notConfigured }

        let callbackURL = try await startOAuthFlow()
        let code = try extractCode(from: callbackURL)
        let token = try await exchangeCode(code)
        let (email, name) = try await fetchUserInfo(token: token)

        let account = Account(email: email, displayName: name)
        try OAuthToken.save(token, accountId: account.id)
        return (account, token)
    }

    func refreshToken(for accountId: String) async throws -> OAuthToken {
        guard var token = OAuthToken.load(accountId: accountId) else { throw AuthError.noToken }
        guard token.isExpired else { return token }

        let params = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": token.refreshToken,
            "grant_type": "refresh_token",
        ]
        let data = try await postForm(url: tokenURL, params: params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        token.accessToken = json["access_token"] as! String
        let expiresIn = json["expires_in"] as? Int ?? 3600
        token.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        try OAuthToken.save(token, accountId: accountId)
        return token
    }

    // MARK: - Private

    private func startOAuthFlow() async throws -> URL {
        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        NSWorkspace.shared.open(components.url!)

        return try await withCheckedThrowingContinuation { cont in
            self.pendingContinuation = cont
        }
    }

    @objc private func handleCallback(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        pendingContinuation?.resume(returning: url)
        pendingContinuation = nil
    }

    private func extractCode(from url: URL) throws -> String {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value else {
            let error = comps?.queryItems?.first(where: { $0.name == "error" })?.value ?? "unknown"
            throw AuthError.oauthError(error)
        }
        return code
    }

    private func exchangeCode(_ code: String) async throws -> OAuthToken {
        let params = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
        ]
        let data = try await postForm(url: tokenURL, params: params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let expiresIn = json["expires_in"] as? Int ?? 3600
        return OAuthToken(
            accessToken: json["access_token"] as! String,
            refreshToken: json["refresh_token"] as! String,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            tokenType: json["token_type"] as? String ?? "Bearer"
        )
    }

    private func fetchUserInfo(token: OAuthToken) async throws -> (email: String, name: String) {
        var request = URLRequest(url: URL(string: userinfoURL)!)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return (json["email"] as? String ?? "", json["name"] as? String ?? "")
    }

    private func postForm(url: String, params: [String: String]) async throws -> Data {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params.map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
            .joined(separator: "&").data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}

enum AuthError: Error, LocalizedError {
    case notConfigured
    case noToken
    case oauthError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Google OAuth credentials not configured. Add Secrets.plist."
        case .noToken: return "No auth token found for this account."
        case .oauthError(let msg): return "OAuth error: \(msg)"
        }
    }
}

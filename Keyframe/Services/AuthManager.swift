import Foundation

@MainActor
@Observable
final class AuthManager {
    enum Status: Equatable {
        case idle
        case authenticating
        case authenticated
        case failed(String)
    }

    var status: Status = .idle
    private let oauthService = OAuthService()

    // MARK: - API key auth

    func loginWithAPIKey(_ key: String) {
        guard !key.isEmpty else {
            status = .failed("API key cannot be empty")
            return
        }
        do {
            try KeychainService.save(.apiKey, value: key)
            status = .authenticated
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func storedAPIKey() -> String? {
        KeychainService.load(.apiKey)
    }

    // MARK: - OAuth (ChatGPT / Codex)

    func loginWithOAuth() async {
        status = .authenticating
        do {
            let tokens = try await oauthService.startAuthorization()
            try KeychainService.save(.oauthAccessToken, value: tokens.accessToken)
            if let refresh = tokens.refreshToken {
                try KeychainService.save(.oauthRefreshToken, value: refresh)
            }
            status = .authenticated
        } catch is CancellationError {
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func cancelOAuth() async {
        await oauthService.cancel()
        status = .idle
    }

    func storedOAuthTokens() -> (accessToken: String, refreshToken: String?)? {
        guard let accessToken = KeychainService.load(.oauthAccessToken) else { return nil }
        let refreshToken = KeychainService.load(.oauthRefreshToken)
        return (accessToken, refreshToken)
    }

    func refreshOAuthToken() async -> Bool {
        guard let refreshToken = KeychainService.load(.oauthRefreshToken) else { return false }
        do {
            let tokens = try await oauthService.refreshAccessToken(refreshToken: refreshToken)
            try KeychainService.save(.oauthAccessToken, value: tokens.accessToken)
            if let newRefresh = tokens.refreshToken {
                try KeychainService.save(.oauthRefreshToken, value: newRefresh)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Codex CLI token detection

    func detectCodexTokens() -> CodexDetector.DetectedTokens? {
        CodexDetector.detect()
    }

    func loginWithCodexTokens(_ tokens: CodexDetector.DetectedTokens) {
        do {
            try KeychainService.save(.oauthAccessToken, value: tokens.accessToken)
            if let refresh = tokens.refreshToken {
                try KeychainService.save(.oauthRefreshToken, value: refresh)
            }
            status = .authenticated
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Resolve current AuthMode for AppState

    func resolveAuthMode() -> AuthMode {
        if let oauth = storedOAuthTokens() {
            return .oauth(accessToken: oauth.accessToken, refreshToken: oauth.refreshToken)
        }
        if let apiKey = storedAPIKey() {
            return .apiKey(apiKey)
        }
        return .none
    }

    // MARK: - Logout

    func logout() {
        KeychainService.deleteAll()
        status = .idle
    }
}

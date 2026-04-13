import Foundation

protocol KeyframeOAuthClient: Actor {
    func startAuthorization() async throws -> OAuthService.Tokens
    func cancel() async
    func refreshAccessToken(refreshToken: String) async throws -> OAuthService.Tokens
}

extension OAuthService: KeyframeOAuthClient {}

@MainActor
@Observable
final class AuthManager {
    private static let missingAccountIdMessage =
        OpenAIService.ServiceError.missingAccountId.errorDescription ??
        "ChatGPT account ID not found. Please sign out and sign in again."

    enum Status: Equatable {
        case idle
        case authenticating
        case authenticated
        case failed(String)
    }

    var status: Status = .idle
    private let oauthService: any KeyframeOAuthClient

    init(oauthService: any KeyframeOAuthClient = OAuthService()) {
        self.oauthService = oauthService
    }

    nonisolated static func persistedOAuthValues(
        from tokens: OAuthService.Tokens,
        fallbackAccountId: String? = nil
    ) -> [KeychainService.Key: String?] {
        [
            .oauthAccessToken: tokens.accessToken,
            .oauthRefreshToken: tokens.refreshToken,
            .oauthAccountId: tokens.accountId ?? fallbackAccountId,
        ]
    }

    // MARK: - OAuth (ChatGPT / Codex)

    func loginWithOAuth() async {
        status = .authenticating
        do {
            let tokens = try await oauthService.startAuthorization()
            clearLegacyAPIKey()
            try KeychainService.save(Self.persistedOAuthValues(from: tokens))
            _ = resolveAuthMode()
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

    func storedOAuthTokens() -> (accessToken: String, refreshToken: String?, accountId: String?)? {
        guard let accessToken = KeychainService.load(.oauthAccessToken) else { return nil }
        let refreshToken = KeychainService.load(.oauthRefreshToken)
        let accountId = KeychainService.load(.oauthAccountId)
        return (accessToken, refreshToken, accountId)
    }

    func refreshOAuthToken() async -> Bool {
        guard let refreshToken = KeychainService.load(.oauthRefreshToken) else { return false }
        do {
            let tokens = try await oauthService.refreshAccessToken(refreshToken: refreshToken)
            try KeychainService.save(
                Self.persistedOAuthValues(
                    from: tokens,
                    fallbackAccountId: storedOAuthTokens()?.accountId
                )
            )
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
            clearLegacyAPIKey()
            try KeychainService.save(
                Self.persistedOAuthValues(
                    from: .init(
                        accessToken: tokens.accessToken,
                        refreshToken: tokens.refreshToken,
                        idToken: nil,
                        expiresIn: nil,
                        accountId: tokens.accountId
                    )
                )
            )
            _ = resolveAuthMode()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Resolve current AuthMode for AppState

    func resolveAuthMode() -> AuthMode {
        clearLegacyAPIKey()
        if let oauth = storedOAuthTokens() {
            if let accountId = oauth.accountId, !accountId.isEmpty {
                status = .authenticated
            } else {
                status = .failed(Self.missingAccountIdMessage)
            }
            return .oauth(accessToken: oauth.accessToken, refreshToken: oauth.refreshToken, accountId: oauth.accountId)
        }
        status = .idle
        return .none
    }

    // MARK: - Logout

    func logout() {
        KeychainService.deleteAll()
        status = .idle
    }

    private func clearLegacyAPIKey() {
        KeychainService.delete(.apiKey)
    }
}

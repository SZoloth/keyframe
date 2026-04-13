import Testing
import Foundation
@testable import Keyframe

@Suite("Auth services", .serialized)
struct AuthTests {

    // MARK: - CodexDetector

    @Test func codexDetectorParsesValidAuth() throws {
        let json = """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "access_token": "eyJhbGciOiJSUzI1...",
            "refresh_token": "rt_BaFnCHAUVz...",
            "account_id": "fdd387ac-a196-4eba-..."
          },
          "last_refresh": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
        let tmpFile = NSTemporaryDirectory() + "test-codex-auth-\(UUID().uuidString).json"
        try json.write(toFile: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        let tokens = CodexDetector.detect(at: tmpFile)
        #expect(tokens != nil)
        #expect(tokens?.accessToken == "eyJhbGciOiJSUzI1...")
        #expect(tokens?.refreshToken == "rt_BaFnCHAUVz...")
        #expect(tokens?.accountId == "fdd387ac-a196-4eba-...")
    }

    @Test func codexDetectorRejectsStaleTokens() throws {
        let staleDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let json = """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "access_token": "eyJ...",
            "refresh_token": "rt_..."
          },
          "last_refresh": "\(ISO8601DateFormatter().string(from: staleDate))"
        }
        """
        let tmpFile = NSTemporaryDirectory() + "test-codex-stale-\(UUID().uuidString).json"
        try json.write(toFile: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        #expect(CodexDetector.detect(at: tmpFile) == nil)
    }

    @Test func codexDetectorRejectsNonChatgptMode() throws {
        let json = """
        {
          "auth_mode": "api_key",
          "tokens": { "access_token": "sk-..." },
          "last_refresh": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
        let tmpFile = NSTemporaryDirectory() + "test-codex-apikey-\(UUID().uuidString).json"
        try json.write(toFile: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        #expect(CodexDetector.detect(at: tmpFile) == nil)
    }

    @Test func codexDetectorHandlesMissingFile() {
        #expect(CodexDetector.detect(at: "/nonexistent/path/auth.json") == nil)
    }

    // MARK: - AuthManager

    @MainActor @Test func authManagerCodexTokenImport() {
        let manager = AuthManager()
        manager.logout()
        let tokens = CodexDetector.DetectedTokens(
            accessToken: "imported-access-token",
            refreshToken: "imported-refresh-token",
            accountId: "acc-imported"
        )
        manager.loginWithCodexTokens(tokens)
        #expect(manager.status == .authenticated)

        let oauth = manager.storedOAuthTokens()
        #expect(oauth?.accessToken == "imported-access-token")
        #expect(oauth?.refreshToken == "imported-refresh-token")
        #expect(oauth?.accountId == "acc-imported")

        let mode = manager.resolveAuthMode()
        if case .oauth(let access, let refresh, let accountId) = mode {
            #expect(access == "imported-access-token")
            #expect(refresh == "imported-refresh-token")
            #expect(accountId == "acc-imported")
        } else {
            Issue.record("Expected .oauth mode")
        }

        manager.logout()
    }

    @MainActor @Test func authManagerIgnoresLegacyAPIKeyDuringResolution() throws {
        let manager = AuthManager()
        manager.logout()
        try KeychainService.save(.apiKey, value: "sk-legacy")

        let mode = manager.resolveAuthMode()
        #expect(mode == .none)
        #expect(KeychainService.load(.apiKey) == nil)
    }

    @Test func persistedOAuthValuesPreserveExistingAccountIdWhenRefreshOmitsIt() {
        let refreshed = OAuthService.Tokens(
            accessToken: "new-access-token",
            refreshToken: "new-refresh-token",
            idToken: nil,
            expiresIn: 3600,
            accountId: nil
        )

        let values = AuthManager.persistedOAuthValues(
            from: refreshed,
            fallbackAccountId: "acc-existing"
        )

        #expect(values[.oauthAccessToken] == "new-access-token")
        #expect(values[.oauthRefreshToken] == "new-refresh-token")
        #expect(values[.oauthAccountId] == "acc-existing")
    }

    @MainActor @Test func resolveAuthModeWithoutAccountIdSetsFailedStatus() throws {
        let manager = AuthManager()
        manager.logout()
        try KeychainService.save([
            .oauthAccessToken: "tok-missing-account",
            .oauthRefreshToken: "rt-missing-account",
            .oauthAccountId: nil,
        ])

        let mode = manager.resolveAuthMode()
        if case .oauth(let access, let refresh, let accountId) = mode {
            #expect(access == "tok-missing-account")
            #expect(refresh == "rt-missing-account")
            #expect(accountId == nil)
        } else {
            Issue.record("Expected .oauth mode")
        }

        #expect(
            manager.status ==
            .failed("ChatGPT account ID not found. Please sign out and sign in again.")
        )
        manager.logout()
    }

    // MARK: - Auth mode to endpoint routing

    @MainActor @Test func oauthAuthModeRoutesCodexBackend() {
        let manager = AuthManager()
        manager.logout()
        let tokens = CodexDetector.DetectedTokens(
            accessToken: "tok-route",
            refreshToken: "rt-route",
            accountId: "acc-route"
        )
        manager.loginWithCodexTokens(tokens)
        let mode = manager.resolveAuthMode()
        if case .oauth(let access, _, let accountId) = mode {
            #expect(access == "tok-route")
            #expect(accountId == "acc-route")
        } else {
            Issue.record("Expected .oauth mode")
        }
        manager.logout()
    }

    @MainActor @Test func logoutClearsAllCredentials() {
        let manager = AuthManager()
        manager.loginWithCodexTokens(.init(
            accessToken: "tok-clear-test",
            refreshToken: "rt-clear-test",
            accountId: "acc-clear-test"
        ))
        #expect(manager.status == .authenticated)

        manager.logout()
        #expect(manager.resolveAuthMode() == .none)
        #expect(manager.storedOAuthTokens() == nil)
        #expect(KeychainService.load(.apiKey) == nil)
    }

    @MainActor @Test func refreshOAuthTokenUsesInjectedClientAndPreservesAccountId() async throws {
        let fakeClient = FakeOAuthClient(
            refreshResult: .success(
                .init(
                    accessToken: "tok-refreshed",
                    refreshToken: "rt-refreshed",
                    idToken: nil,
                    expiresIn: 3600,
                    accountId: nil
                )
            )
        )
        let manager = AuthManager(oauthService: fakeClient)
        manager.logout()
        try KeychainService.save([
            .oauthAccessToken: "tok-old",
            .oauthRefreshToken: "rt-old",
            .oauthAccountId: "acc-existing",
        ])

        let success = await manager.refreshOAuthToken()
        #expect(success == true)
        #expect(await fakeClient.lastRefreshToken() == "rt-old")

        let oauth = manager.storedOAuthTokens()
        #expect(oauth?.accessToken == "tok-refreshed")
        #expect(oauth?.refreshToken == "rt-refreshed")
        #expect(oauth?.accountId == "acc-existing")
        manager.logout()
    }

    @MainActor @Test func loginWithOAuthUsesInjectedClient() async {
        let fakeClient = FakeOAuthClient(
            startResult: .success(
                .init(
                    accessToken: "tok-oauth",
                    refreshToken: "rt-oauth",
                    idToken: nil,
                    expiresIn: 3600,
                    accountId: "acc-oauth"
                )
            )
        )
        let manager = AuthManager(oauthService: fakeClient)
        manager.logout()

        await manager.loginWithOAuth()

        #expect(manager.status == .authenticated)
        let oauth = manager.storedOAuthTokens()
        #expect(oauth?.accessToken == "tok-oauth")
        #expect(oauth?.refreshToken == "rt-oauth")
        #expect(oauth?.accountId == "acc-oauth")
        manager.logout()
    }

    @MainActor @Test func cancelOAuthUsesInjectedClient() async {
        let fakeClient = FakeOAuthClient()
        let manager = AuthManager(oauthService: fakeClient)

        await manager.cancelOAuth()

        #expect(manager.status == .idle)
        #expect(await fakeClient.didCancel() == true)
    }

    // MARK: - PKCE helpers

    @Test func base64URLEncodingRemovesPaddingAndSpecialChars() {
        let data = Data([0xFF, 0xFE, 0xFD, 0xFC])
        let encoded = data.base64URLEncoded()
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }
}

@Suite("OAuth transport simulation", .serialized)
struct OAuthTransportSimulationTests {
    @Test func refreshAccessTokenSendsExpectedRequestBody() async throws {
        let responseJSON: [String: Any] = [
            "access_token": "tok-new",
            "expires_in": 3600
        ]
        let transport = RecordingOAuthTransport(
            responses: [
                .init(
                    statusCode: 200,
                    body: try JSONSerialization.data(withJSONObject: responseJSON)
                )
            ]
        )
        let service = OAuthService(transport: transport)

        let tokens = try await service.refreshAccessToken(refreshToken: "rt-old")
        #expect(tokens.accessToken == "tok-new")
        #expect(tokens.refreshToken == "rt-old")

        guard let request = await transport.requests().first else {
            Issue.record("Expected a captured OAuth request"); return
        }

        #expect(request.url == "https://auth.openai.com/oauth/token")
        #expect(request.method == "POST")
        #expect(request.headers["Content-Type"] == "application/json")

        let body = try request.jsonBody()
        #expect(body["grant_type"] as? String == "refresh_token")
        #expect(body["refresh_token"] as? String == "rt-old")
        #expect(body["client_id"] as? String == "app_EMoamEEZ73f0CkXaXp7hrann")
    }
}

private actor FakeOAuthClient: KeyframeOAuthClient {
    private let startResult: Result<OAuthService.Tokens, Error>
    private let refreshResult: Result<OAuthService.Tokens, Error>
    private var cancelCalled = false
    private var seenRefreshToken: String?

    init(
        startResult: Result<OAuthService.Tokens, Error> = .failure(CancellationError()),
        refreshResult: Result<OAuthService.Tokens, Error> = .failure(CancellationError())
    ) {
        self.startResult = startResult
        self.refreshResult = refreshResult
    }

    func startAuthorization() async throws -> OAuthService.Tokens {
        try startResult.get()
    }

    func cancel() async {
        cancelCalled = true
    }

    func refreshAccessToken(refreshToken: String) async throws -> OAuthService.Tokens {
        seenRefreshToken = refreshToken
        return try refreshResult.get()
    }

    func didCancel() -> Bool {
        cancelCalled
    }

    func lastRefreshToken() -> String? {
        seenRefreshToken
    }
}

private struct CapturedOAuthRequest: Sendable {
    let url: String
    let method: String
    let headers: [String: String]
    let bodyData: Data?

    init(_ request: URLRequest) {
        self.url = request.url?.absoluteString ?? ""
        self.method = request.httpMethod ?? ""
        self.headers = request.allHTTPHeaderFields ?? [:]
        self.bodyData = request.httpBody
    }

    func jsonBody() throws -> [String: Any] {
        guard let bodyData else { return [:] }
        return try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] ?? [:]
    }
}

private actor RecordingOAuthTransport: OAuthTransport {
    private var responses: [OAuthHTTPResponse]
    private var capturedRequests: [CapturedOAuthRequest] = []

    init(responses: [OAuthHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> OAuthHTTPResponse {
        capturedRequests.append(CapturedOAuthRequest(request))
        guard !responses.isEmpty else {
            return OAuthHTTPResponse(statusCode: 500, body: Data())
        }
        return responses.removeFirst()
    }

    func requests() -> [CapturedOAuthRequest] {
        capturedRequests
    }
}

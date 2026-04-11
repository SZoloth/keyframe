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

    // MARK: - PKCE helpers

    @Test func base64URLEncodingRemovesPaddingAndSpecialChars() {
        let data = Data([0xFF, 0xFE, 0xFD, 0xFC])
        let encoded = data.base64URLEncoded()
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }
}

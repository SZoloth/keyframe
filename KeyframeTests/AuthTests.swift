import Testing
import Foundation
@testable import Keyframe

@Suite("Auth services", .serialized)
struct AuthTests {

    // MARK: - Keychain

    @Test func keychainSaveAndLoad() throws {
        try KeychainService.save(.apiKey, value: "sk-test-12345")
        let loaded = KeychainService.load(.apiKey)
        #expect(loaded == "sk-test-12345")
        KeychainService.delete(.apiKey)
    }

    @Test func keychainOverwrite() throws {
        try KeychainService.save(.apiKey, value: "first")
        try KeychainService.save(.apiKey, value: "second")
        #expect(KeychainService.load(.apiKey) == "second")
        KeychainService.delete(.apiKey)
    }

    @Test func keychainDeleteRemovesValue() throws {
        try KeychainService.save(.apiKey, value: "to-delete")
        KeychainService.delete(.apiKey)
        #expect(KeychainService.load(.apiKey) == nil)
    }

    @Test func keychainLoadMissingReturnsNil() {
        KeychainService.delete(.oauthAccountId)
        #expect(KeychainService.load(.oauthAccountId) == nil)
    }

    @Test func keychainDeleteAll() throws {
        try KeychainService.save(.apiKey, value: "key")
        try KeychainService.save(.oauthAccessToken, value: "token")
        KeychainService.deleteAll()
        #expect(KeychainService.load(.apiKey) == nil)
        #expect(KeychainService.load(.oauthAccessToken) == nil)
    }

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

    @MainActor @Test func authManagerAPIKeyFlow() {
        let manager = AuthManager()
        manager.loginWithAPIKey("sk-test-key-123")
        #expect(manager.status == .authenticated)
        #expect(manager.storedAPIKey() == "sk-test-key-123")

        let mode = manager.resolveAuthMode()
        if case .apiKey(let key) = mode {
            #expect(key == "sk-test-key-123")
        } else {
            Issue.record("Expected .apiKey mode")
        }

        manager.logout()
        #expect(manager.status == .idle)
        #expect(manager.storedAPIKey() == nil)
        #expect(manager.resolveAuthMode() == .none)
    }

    @MainActor @Test func authManagerRejectsEmptyAPIKey() {
        let manager = AuthManager()
        manager.loginWithAPIKey("")
        if case .failed = manager.status {
            // expected
        } else {
            Issue.record("Expected .failed status for empty key")
        }
    }

    @MainActor @Test func authManagerCodexTokenImport() {
        let manager = AuthManager()
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

    // MARK: - PKCE helpers

    @Test func base64URLEncodingRemovesPaddingAndSpecialChars() {
        let data = Data([0xFF, 0xFE, 0xFD, 0xFC])
        let encoded = data.base64URLEncoded()
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }
}

import Foundation
import Network
import CryptoKit
import AppKit

struct OAuthHTTPResponse: Sendable {
    let statusCode: Int
    let body: Data
}

protocol OAuthTransport: Sendable {
    func data(for request: URLRequest) async throws -> OAuthHTTPResponse
}

struct URLSessionOAuthTransport: OAuthTransport {
    func data(for request: URLRequest) async throws -> OAuthHTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return OAuthHTTPResponse(statusCode: statusCode, body: data)
    }
}

actor OAuthService {
    struct Config {
        var clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
        var issuerBaseURL = "https://auth.openai.com"
        var redirectPort: UInt16 = 1455
        var scopes = "openid profile email offline_access"

        var authorizationURL: String { "\(issuerBaseURL)/oauth/authorize" }
        var tokenURL: String { "\(issuerBaseURL)/oauth/token" }
        var redirectURI: String { "http://localhost:\(redirectPort)/auth/callback" }
    }

    struct Tokens {
        let accessToken: String
        let refreshToken: String?
        let idToken: String?
        let expiresIn: Int?
        let accountId: String?
    }

    enum OAuthError: LocalizedError {
        case pkceGenerationFailed
        case listenerFailed(String)
        case noAuthorizationCode
        case tokenExchangeFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .pkceGenerationFailed: return "Failed to generate PKCE challenge"
            case .listenerFailed(let msg): return "OAuth listener failed: \(msg)"
            case .noAuthorizationCode: return "No authorization code received"
            case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
            case .cancelled: return "Authentication cancelled"
            }
        }
    }

    private let config: Config
    private let transport: any OAuthTransport
    private var listener: NWListener?
    private var authContinuation: CheckedContinuation<String, any Error>?

    init(
        config: Config = Config(),
        transport: any OAuthTransport = URLSessionOAuthTransport()
    ) {
        self.config = config
        self.transport = transport
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded()
    }

    // MARK: - Authorization flow

    func startAuthorization() async throws -> Tokens {
        if authContinuation != nil {
            stopListener()
            authContinuation?.resume(throwing: OAuthError.cancelled)
            authContinuation = nil
        }

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = UUID().uuidString

        let authURL = buildAuthorizationURL(
            codeChallenge: codeChallenge,
            state: state
        )

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, any Error>) in
            self.authContinuation = continuation
            startListener(expectedState: state)
            openBrowser(url: authURL)
        }

        return try await exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier
        )
    }

    func cancel() {
        stopListener()
        authContinuation?.resume(throwing: OAuthError.cancelled)
        authContinuation = nil
    }

    // MARK: - URL construction

    private func buildAuthorizationURL(codeChallenge: String, state: String) -> URL {
        var components = URLComponents(string: config.authorizationURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url!
    }

    // MARK: - Local HTTP listener

    private func startListener(expectedState: String) {
        let params = NWParameters.tcp
        let port = NWEndpoint.Port(rawValue: config.redirectPort)!

        do {
            listener = try NWListener(using: params, on: port)
        } catch {
            authContinuation?.resume(throwing: OAuthError.listenerFailed(error.localizedDescription))
            authContinuation = nil
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task { await self.handleConnection(connection, expectedState: expectedState) }
        }

        listener?.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                guard let self else { return }
                Task {
                    await self.resumeWithError(.listenerFailed(error.localizedDescription))
                }
            }
        }

        listener?.start(queue: .main)
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection, expectedState: String) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else { return }

            Task {
                await self.processHTTPRequest(request, connection: connection, expectedState: expectedState)
            }
        }
    }

    private func processHTTPRequest(_ request: String, connection: NWConnection, expectedState: String) {
        guard let firstLine = request.split(separator: "\r\n").first,
              let pathPart = firstLine.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: String(pathPart)),
              components.path == "/auth/callback"
        else {
            sendResponse(connection: connection, statusCode: 404, body: "Not found")
            return
        }

        let queryItems = components.queryItems ?? []

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value ?? error
            sendResponse(connection: connection, statusCode: 400, body: "Authentication failed: \(description)")
            stopListener()
            authContinuation?.resume(throwing: OAuthError.tokenExchangeFailed(description))
            authContinuation = nil
            return
        }

        guard let receivedState = queryItems.first(where: { $0.name == "state" })?.value,
              receivedState == expectedState
        else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid state parameter")
            return
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            sendResponse(connection: connection, statusCode: 400, body: "No authorization code")
            stopListener()
            authContinuation?.resume(throwing: OAuthError.noAuthorizationCode)
            authContinuation = nil
            return
        }

        sendResponse(connection: connection, statusCode: 200, body: successHTML)
        stopListener()
        authContinuation?.resume(returning: code)
        authContinuation = nil
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let statusText = statusCode == 200 ? "OK" : "Error"
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: text/html\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Token exchange

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> Tokens {
        var request = URLRequest(url: URL(string: config.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirectURI,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await transport.data(for: request)

        guard (200...299).contains(response.statusCode) else {
            let errorBody = String(data: response.body, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.tokenExchangeFailed(errorBody)
        }

        let json = try JSONSerialization.jsonObject(with: response.body) as? [String: Any] ?? [:]

        guard let accessToken = json["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed("No access_token in response")
        }

        let idToken = json["id_token"] as? String
        let accountId = idToken.flatMap(Self.extractAccountId) ?? Self.extractAccountId(from: accessToken)

        return Tokens(
            accessToken: accessToken,
            refreshToken: json["refresh_token"] as? String,
            idToken: idToken,
            expiresIn: json["expires_in"] as? Int,
            accountId: accountId
        )
    }

    // MARK: - JWT account ID extraction

    /// Decode a JWT payload (no signature verification — the TLS channel provides integrity).
    private static func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Try multiple claim paths used by OpenAI tokens.
    private static func extractAccountId(from jwt: String) -> String? {
        guard let claims = decodeJWTPayload(jwt) else { return nil }

        if let id = claims["chatgpt_account_id"] as? String { return id }

        if let authClaims = claims["https://api.openai.com/auth"] as? [String: Any],
           let id = authClaims["chatgpt_account_id"] as? String { return id }

        if let orgs = claims["organizations"] as? [[String: Any]],
           let id = orgs.first?["id"] as? String { return id }

        return nil
    }

    // MARK: - Token refresh

    func refreshAccessToken(refreshToken: String) async throws -> Tokens {
        var request = URLRequest(url: URL(string: config.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": config.clientId,
            "refresh_token": refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await transport.data(for: request)

        guard (200...299).contains(response.statusCode) else {
            let errorBody = String(data: response.body, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.tokenExchangeFailed(errorBody)
        }

        let json = try JSONSerialization.jsonObject(with: response.body) as? [String: Any] ?? [:]

        guard let accessToken = json["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed("No access_token in refresh response")
        }

        let idToken = json["id_token"] as? String
        let accountId = idToken.flatMap(Self.extractAccountId) ?? Self.extractAccountId(from: accessToken)

        return Tokens(
            accessToken: accessToken,
            refreshToken: json["refresh_token"] as? String ?? refreshToken,
            idToken: idToken,
            expiresIn: json["expires_in"] as? Int,
            accountId: accountId
        )
    }

    // MARK: - Browser

    private nonisolated func openBrowser(url: URL) {
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }

    private func resumeWithError(_ error: OAuthError) {
        authContinuation?.resume(throwing: error)
        authContinuation = nil
    }

    // MARK: - Success page

    private var successHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head><title>Keyframe — Authenticated</title>
        <style>
        body { font-family: -apple-system, sans-serif; display: flex; justify-content: center;
               align-items: center; height: 100vh; margin: 0; background: #f5f5f5; }
        .card { text-align: center; padding: 48px; background: white; border-radius: 12px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        h1 { font-size: 24px; margin-bottom: 8px; }
        p { color: #666; }
        </style></head>
        <body><div class="card">
        <h1>Authenticated</h1>
        <p>You can close this tab and return to Keyframe.</p>
        </div></body></html>
        """
    }
}

// MARK: - Base64 URL encoding

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

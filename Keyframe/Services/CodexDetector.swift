import Foundation

enum CodexDetector {
    struct CodexAuth: Decodable {
        let authMode: String?
        let tokens: Tokens?
        let lastRefresh: String?

        struct Tokens: Decodable {
            let accessToken: String?
            let refreshToken: String?
            let accountId: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case accountId = "account_id"
            }
        }

        enum CodingKeys: String, CodingKey {
            case authMode = "auth_mode"
            case tokens
            case lastRefresh = "last_refresh"
        }
    }

    struct DetectedTokens {
        let accessToken: String
        let refreshToken: String?
    }

    static func detect(at path: String? = nil) -> DetectedTokens? {
        let filePath = path ?? defaultPath()
        guard FileManager.default.fileExists(atPath: filePath),
              let data = FileManager.default.contents(atPath: filePath)
        else { return nil }

        guard let auth = try? JSONDecoder().decode(CodexAuth.self, from: data),
              auth.authMode == "chatgpt",
              let tokens = auth.tokens,
              let accessToken = tokens.accessToken,
              !accessToken.isEmpty
        else { return nil }

        if let lastRefresh = auth.lastRefresh,
           let refreshDate = ISO8601DateFormatter().date(from: lastRefresh),
           Date().timeIntervalSince(refreshDate) > 7 * 24 * 3600 {
            return nil
        }

        return DetectedTokens(
            accessToken: accessToken,
            refreshToken: tokens.refreshToken
        )
    }

    private static func defaultPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.codex/auth.json"
    }
}

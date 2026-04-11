import Foundation
import Security

enum KeychainService {
    private static let service = "com.szoloth.keyframe"
    private static let account = "credentials"
    private static let defaultsKey = "keyframe-credentials"

    enum Key: String, CaseIterable {
        case apiKey = "openai-api-key"
        case oauthAccessToken = "oauth-access-token"
        case oauthRefreshToken = "oauth-refresh-token"
        case oauthAccountId = "oauth-account-id"
    }

    // All credentials stored as one JSON blob — single Keychain prompt.

    private static func loadAll() -> [String: String] {
        if let dict = loadFromKeychain() { return dict }
        return loadFromDefaults()
    }

    private static func saveAll(_ dict: [String: String]) {
        if !saveToKeychain(dict) {
            saveToDefaults(dict)
        }
    }

    static func save(_ key: Key, value: String) throws {
        var dict = loadAll()
        dict[key.rawValue] = value
        saveAll(dict)
    }

    static func save(_ values: [Key: String?]) throws {
        var dict = loadAll()
        for (key, value) in values {
            if let value {
                dict[key.rawValue] = value
            } else {
                dict.removeValue(forKey: key.rawValue)
            }
        }
        saveAll(dict)
    }

    static func load(_ key: Key) -> String? {
        loadAll()[key.rawValue]
    }

    static func delete(_ key: Key) {
        var dict = loadAll()
        dict.removeValue(forKey: key.rawValue)
        if dict.isEmpty {
            deleteAll()
        } else {
            saveAll(dict)
        }
    }

    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    // MARK: - Keychain backend

    private static func loadFromKeychain() -> [String: String]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    private static func saveToKeychain(_ dict: [String: String]) -> Bool {
        guard let data = try? JSONEncoder().encode(dict) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - UserDefaults fallback

    private static func loadFromDefaults() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
    }

    private static func saveToDefaults(_ dict: [String: String]) {
        UserDefaults.standard.set(dict, forKey: defaultsKey)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status \(status)"
        }
    }
}

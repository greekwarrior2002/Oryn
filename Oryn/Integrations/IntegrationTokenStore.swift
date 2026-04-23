import Foundation
import Security

/// Lightweight Keychain-backed storage for integration OAuth tokens.
///
/// Tokens are stored with a stable `account` string (e.g. "outlook-access",
/// "gcal-refresh") so each provider can manage its own credentials without
/// collisions. Nothing sensitive ever lands in UserDefaults.
enum IntegrationTokenStore {

    private static let service = "com.oryn.integrations"

    static func save(_ token: String, forAccount account: String) throws {
        let data = token.data(using: .utf8) ?? Data()
        // Delete any existing item first so SecItemAdd doesn't error with -25299.
        let delQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(delQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:   data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw IntegrationError.authFailed("Keychain save failed (\(status))")
        }
    }

    static func read(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    static func delete(forAccount account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

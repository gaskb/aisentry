import Foundation
import Security

/// Stores provider credentials (cookies, API keys) in the macOS Keychain rather than
/// UserDefaults/plist, since those are plaintext on disk.
enum KeychainStore {
    private static let service = "net.gaskb.usagesentry"

    private static func account(providerId: String, field: String) -> String {
        "\(providerId).\(field)"
    }

    static func save(providerId: String, field: String, value: String) {
        let account = account(providerId: providerId, field: field)
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        guard !value.isEmpty else { return }

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(providerId: String, field: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(providerId: providerId, field: field),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(providerId: String, field: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(providerId: providerId, field: field),
        ]
        SecItemDelete(query as CFDictionary)
    }
}

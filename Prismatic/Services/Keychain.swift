import Foundation
import Security

/// Tiny generic-password wrapper. The account blob includes the Apple ID password (needed to refresh tokens).
enum Keychain {
    private static let service = "dev.prismatic.launcher"
    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }
    static func save(_ data: Data, key: String) {
        SecItemDelete(query(key) as CFDictionary)
        var q = query(key)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
    static func load(key: String) -> Data? {
        var q = query(key); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }
    static func delete(key: String) { SecItemDelete(query(key) as CFDictionary) }
}

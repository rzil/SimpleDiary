
import Foundation
import CryptoKit
import Security

/// Manages storage of the symmetric encryption key in the Keychain.
/// We deliberately keep this simple: biometrics are enforced at the app level,
/// and the key is protected by the macOS login + FileVault + 'whenUnlockedThisDeviceOnly'.
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "DiaryApp"
    private let account = "journal-encryption-key"

    func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKey() {
            return existing
        }

        let key = SymmetricKey(size: .bits256)
        try saveKey(key)
        return key
    }

    private func loadKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
        }

        return SymmetricKey(data: data)
    }

    private func saveKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
        }
    }
}

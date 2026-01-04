import Foundation
import CryptoKit
import LocalAuthentication
import Security

/// Stores the derived vault key in the Keychain.
/// Biometrics are enforced by the app (via LocalAuthentication)
/// before we ever read this key.
final class BiometricKeychainManager: BiometricKeychainManaging {
    private let service = "SimpleDiary"
    private let account = "vault-key"
    
    private func account(for label: String?) -> String {
        if let label, !label.isEmpty {
            return "vault-key-" + label
        } else {
            return account
        }
    }
    
    /// Store the vault key in a normal, device-only Keychain item.
    func storeKey(_ key: SymmetricKey) throws {
        try deleteKey() // remove any existing
        
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
    
    func storeKey(_ key: SymmetricKey, label: String) throws {
        // Delete any existing labeled key first
        try deleteKey(label: label)
        
        let data = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: label),
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
        }
    }
    
    /// First run biometrics/passcode via LocalAuthentication, then read the key.
    func loadKeyWithBiometrics(completion: @escaping (Result<SymmetricKey, Error>) -> Void) {
        let context = LAContext()
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        var authError: NSError?
        guard context.canEvaluatePolicy(policy, error: &authError) else {
            completion(.failure(authError ?? NSError(domain: "LAError", code: -1)))
            return
        }
        
        context.evaluatePolicy(policy, localizedReason: "Unlock your journal") { success, error in
            if !success {
                DispatchQueue.main.async {
                    completion(.failure(error ?? NSError(domain: "LAError", code: -1)))
                }
                return
            }
            
            // Biometrics/passcode OK; now read the key from Keychain.
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: self.account,
                kSecReturnData as String: true
            ]
            
            DispatchQueue.global().async {
                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                
                DispatchQueue.main.async {
                    if status == errSecSuccess, let data = item as? Data {
                        let key = SymmetricKey(data: data)
                        completion(.success(key))
                    } else {
                        let err = NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
                        completion(.failure(err))
                    }
                }
            }
        }
    }
    
    func loadKeyWithBiometrics(label: String, completion: @escaping (Result<SymmetricKey, Error>) -> Void) {
        let context = LAContext()
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        var authError: NSError?
        guard context.canEvaluatePolicy(policy, error: &authError) else {
            completion(.failure(authError ?? NSError(domain: "LAError", code: -1)))
            return
        }
        
        context.evaluatePolicy(policy, localizedReason: "Unlock your journal") { success, error in
            if !success {
                DispatchQueue.main.async {
                    completion(.failure(error ?? NSError(domain: "LAError", code: -1)))
                }
                return
            }
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: self.account(for: label),
                kSecReturnData as String: true
            ]
            
            DispatchQueue.global().async {
                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                
                DispatchQueue.main.async {
                    if status == errSecSuccess, let data = item as? Data {
                        let key = SymmetricKey(data: data)
                        completion(.success(key))
                    } else {
                        let err = NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
                        completion(.failure(err))
                    }
                }
            }
        }
    }
    
    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
        }
    }
    
    func deleteKey(label: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: label)
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
        }
    }
}

import Combine
import Foundation
import CryptoKit

@MainActor
final class AppState: ObservableObject {
    enum Mode {
        case initializing
        case needsSetup
        case locked
        case unlocked
    }
    
    @Published var mode: Mode = .initializing
    @Published var vaultMeta: VaultMeta?
    @Published var journalStore: JournalStore?
    @Published var lastActivity: Date? = nil
    
    private(set) var currentKey: SymmetricKey?
    
    private let fileManager = FileManager.default
    private let baseDir: URL
    let metaURL: URL
    let entriesURL: URL
    
    private let biometricManager = BiometricKeychainManager()
    
    init() {
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("DiaryApp", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appSupport.path) {
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        
        self.baseDir = appSupport
        self.metaURL = appSupport.appendingPathComponent("vault_meta.json")
        self.entriesURL = appSupport.appendingPathComponent("entries.bin")
    }
    
    func initialize() async {
        if fileManager.fileExists(atPath: metaURL.path) {
            do {
                let data = try Data(contentsOf: metaURL)
                let meta = try JSONDecoder().decode(VaultMeta.self, from: data)
                self.vaultMeta = meta
                self.mode = .locked
            } catch {
                print("Failed to load meta:", error)
                self.mode = .needsSetup
            }
        } else {
            self.mode = .needsSetup
        }
    }
    
    // MARK: - Setup
    
    func setupVault(password: String) {
        do {
            let salt = try RandomBytes.generate(count: 32)
            let iterations = 100_000
            let keyData = try PBKDF2.deriveKey(
                password: password,
                salt: salt,
                iterations: iterations,
                keyLength: 32
            )
            let key = SymmetricKey(data: keyData)
            self.currentKey = key
            
            let meta = VaultMeta(
                saltBase64: salt.base64EncodedString(),
                iterations: iterations,
                biometricsEnabled: false,
                autoLockTimeoutSeconds: 5 * 60
            )
            try saveMeta(meta)
            self.vaultMeta = meta
            
            let store = try JournalStore(key: key, baseDir: baseDir)
            self.journalStore = store
            self.mode = .unlocked
            self.noteActivity()
        } catch {
            print("Failed to setup vault:", error)
            self.mode = .needsSetup
        }
    }
    
    // MARK: - Unlock
    
    func unlockWithPassword(_ password: String) {
        guard let meta = vaultMeta else { return }
        do {
            guard let salt = Data(base64Encoded: meta.saltBase64) else {
                throw NSError(domain: "VaultError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid salt"])
            }
            let keyData = try PBKDF2.deriveKey(
                password: password,
                salt: salt,
                iterations: meta.iterations,
                keyLength: 32
            )
            let key = SymmetricKey(data: keyData)
            
            let store = try JournalStore(key: key, baseDir: baseDir)
            // Try loading to ensure key is correct
            try store.load()
            
            self.currentKey = key
            self.journalStore = store
            self.mode = .unlocked
            self.noteActivity()
        } catch {
            print("Unlock failed:", error)
            // Could expose an error message via @Published if you want
        }
    }
    
    func unlockWithBiometrics() {
        guard let meta = vaultMeta, meta.biometricsEnabled else { return }
        biometricManager.loadKeyWithBiometrics { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let key):
                    do {
                        let store = try JournalStore(key: key, baseDir: self.baseDir)
                        try store.load()
                        self.currentKey = key
                        self.journalStore = store
                        self.mode = .unlocked
                        self.noteActivity()
                    } catch {
                        print("Biometric unlock failed:", error)
                    }
                case .failure(let error):
                    print("Biometric key load failed:", error)
                }
            }
        }
    }
    
    func lock() {
        currentKey = nil
        journalStore = nil
        mode = .locked
    }
    
    // MARK: - Biometrics settings
    
    func setBiometricsEnabled(_ enabled: Bool) {
        guard var meta = vaultMeta else { return }
        if enabled {
            guard let key = currentKey else { return }
            do {
                try biometricManager.storeKey(key)
                meta.biometricsEnabled = true
                try saveMeta(meta)
                self.vaultMeta = meta
            } catch {
                print("Failed to enable biometrics:", error)
            }
        } else {
            do {
                try biometricManager.deleteKey()
                meta.biometricsEnabled = false
                try saveMeta(meta)
                self.vaultMeta = meta
            } catch {
                print("Failed to disable biometrics:", error)
            }
        }
    }
    
    // MARK: - Meta
    
    private func saveMeta(_ meta: VaultMeta) throws {
        let data = try JSONEncoder().encode(meta)
        try data.write(to: metaURL, options: [.atomic])
    }

    func setVaultMeta(_ newMeta: VaultMeta) throws {
        try saveMeta(newMeta)
        self.vaultMeta = newMeta
    }

    // MARK: - Change master password
    
    func changePassword(currentPassword: String, newPassword: String) throws {
        guard let meta = vaultMeta else {
            throw NSError(domain: "VaultError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vault not initialized"])
        }
        guard let store = journalStore else {
            throw NSError(domain: "VaultError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Vault must be unlocked to change password"])
        }
        
        // 1. Derive key from current password and verify it matches currentKey
        guard let saltData = Data(base64Encoded: meta.saltBase64) else {
            throw NSError(domain: "VaultError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid salt in metadata"])
        }
        
        let currentKeyData = try PBKDF2.deriveKey(
            password: currentPassword,
            salt: saltData,
            iterations: meta.iterations,
            keyLength: 32
        )
        let derivedCurrentKey = SymmetricKey(data: currentKeyData)
        
        if let existingKey = currentKey {
            // Compare derived key with the one currently in use
            let existingData = existingKey.withUnsafeBytes { Data($0) }
            guard existingData == currentKeyData else {
                throw NSError(domain: "VaultError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Current password is incorrect"])
            }
        } else {
            // No currentKey set (shouldn't happen if we're unlocked), so sanity check by trying to decrypt
            let testStore = try JournalStore(key: derivedCurrentKey, baseDir: baseDir)
            try testStore.load() // will throw if wrong
        }
        
        // 2. Derive new key from new password, with fresh salt
        let newSalt = try RandomBytes.generate(count: 32)
        let newIterations = meta.iterations  // or bump this if you like
        let newKeyData = try PBKDF2.deriveKey(
            password: newPassword,
            salt: newSalt,
            iterations: newIterations,
            keyLength: 32
        )
        let newKey = SymmetricKey(data: newKeyData)
        
        // 3. Re-encrypt the existing entries with the new key
        let crypto = CryptoManager(key: newKey)
        let data = try JSONEncoder().encode(store.entries)
        let encrypted = try crypto.encrypt(data)
        try encrypted.write(to: entriesURL, options: [.atomic])
        
        // 4. Update meta (salt, iterations) and save
        var updatedMeta = meta
        updatedMeta.saltBase64 = newSalt.base64EncodedString()
        updatedMeta.iterations = newIterations
        try saveMeta(updatedMeta)
        self.vaultMeta = updatedMeta
        
        // 5. Update in-memory key and store
        self.currentKey = newKey
        // Recreate the JournalStore with the new key so future saves use it
        let newStore = try JournalStore(key: newKey, baseDir: baseDir)
        self.journalStore = newStore
        newStore.entries = store.entries  // copy entries into the new store
        
        // 6. If biometrics are enabled, refresh the cached key in Keychain
        if updatedMeta.biometricsEnabled {
            do {
                try biometricManager.storeKey(newKey)
            } catch {
                print("Warning: failed to update biometric key after password change:", error)
            }
        }
    }
    
    // MARK: - Activity / idle lock
    
    func noteActivity() {
        lastActivity = Date()
    }
    
    func checkIdleLock() {
        guard mode == .unlocked else { return }
        guard let last = lastActivity else { return }
        
        // Determine timeout: use stored value or default to 5 minutes
        let seconds = vaultMeta?.autoLockTimeoutSeconds ?? (5 * 60)
        if seconds <= 0 { return } // auto-lock disabled
        
        if Date().timeIntervalSince(last) > TimeInterval(seconds) {
            lock()
        }
    }
}

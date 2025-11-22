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
    }
    
    func initialize() async {
        if fileManager.fileExists(atPath: vaultURL.path) {
            do {
                let (header, _) = try VaultFile.read(from: vaultURL)

                let biometricsEnabled = UserDefaults.standard.bool(forKey: "biometricsEnabled")
                let autoLock = UserDefaults.standard.integer(forKey: "autoLockTimeoutSeconds")
                let timeout = autoLock > 0 ? autoLock : (5 * 60)

                self.vaultMeta = VaultMeta(
                    saltBase64: header.saltBase64,
                    iterations: header.iterations,
                    biometricsEnabled: biometricsEnabled,
                    autoLockTimeoutSeconds: timeout,
                    schemaVersion: header.schemaVersion
                )
                self.mode = .locked
            } catch {
                print("Failed to read vault header:", error)
                self.mode = .needsSetup
            }
        } else {
            self.mode = .needsSetup
        }
    }

    private func completeUnlock(with key: SymmetricKey) throws {
        let store = try JournalStore(unlockingWith: key, vaultURL: vaultURL)
        
        // Update in-memory meta from header + stored prefs
        let (header, _) = try VaultFile.read(from: vaultURL)
        let biometricsEnabled = UserDefaults.standard.bool(forKey: "biometricsEnabled")
        let autoLock = UserDefaults.standard.integer(forKey: "autoLockTimeoutSeconds")
        let timeout = autoLock > 0 ? autoLock : (5 * 60)
        
        self.vaultMeta = VaultMeta(
            saltBase64: header.saltBase64,
            iterations: header.iterations,
            biometricsEnabled: biometricsEnabled,
            autoLockTimeoutSeconds: timeout,
            schemaVersion: header.schemaVersion
        )
        
        self.currentKey = key
        self.journalStore = store
        self.mode = .unlocked
        self.noteActivity()
    }

    // MARK: - Setup
    
    func setupVault(password: String) {
        do {
            try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
            
            // KDF params
            let salt = try RandomBytes.generate(count: 32)
            let iterations = 100_000
            
            // Derive key (PBKDF2 as you already have)
            let keyData = try PBKDF2.deriveKey(
                password: password,
                salt: salt,
                iterations: iterations,
                keyLength: 32
            )
            let key = SymmetricKey(data: keyData)
            
            // Create empty entries
            let entries: [JournalEntry] = []
            let json = try JSONEncoder().encode(entries)
            let crypto = CryptoManager(key: key)
            let ciphertext = try crypto.encrypt(json)
            
            // Header
            let header = VaultHeader(
                schemaVersion: 1,
                saltBase64: salt.base64EncodedString(),
                iterations: iterations
            )
            
            // Write single vault file
            try VaultFile.write(to: vaultURL, header: header, ciphertext: ciphertext)
            
            // In-memory state
            self.currentKey = key
            self.vaultMeta = VaultMeta(
                // You can keep VaultMeta as internal in-memory mirror:
                saltBase64: header.saltBase64,
                iterations: header.iterations,
                biometricsEnabled: false,
                autoLockTimeoutSeconds: 5*60,
                schemaVersion: header.schemaVersion
            )
            
            let store = try JournalStore(key: key, vaultURL: vaultURL, header: header)
            store.entries = entries
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
        do {
            let (header, _) = try VaultFile.read(from: vaultURL)
            guard let salt = Data(base64Encoded: header.saltBase64) else {
                throw NSError(domain: "VaultError", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid salt in header"])
            }

            let keyData = try PBKDF2.deriveKey(
                password: password,
                salt: salt,
                iterations: header.iterations,
                keyLength: 32
            )
            let key = SymmetricKey(data: keyData)

            try completeUnlock(with: key)
        } catch CryptoKit.CryptoKitError.authenticationFailure {
            print("Unlock failed: wrong password or corrupted vault")
        } catch {
            print("Unlock failed:", error)
        }
    }

    func unlockWithBiometrics() {
        guard vaultMeta?.biometricsEnabled ?? false else { return }

        biometricManager.loadKeyWithBiometrics { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let key):
                    do {
                        try self.completeUnlock(with: key)
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
        if enabled {
            guard let key = currentKey else { return }
            do {
                try biometricManager.storeKey(key)
                UserDefaults.standard.set(true, forKey: "biometricsEnabled")
                if var meta = vaultMeta {
                    meta.biometricsEnabled = true
                    vaultMeta = meta
                }
            } catch {
                print("Failed to enable biometrics:", error)
            }
        } else {
            do {
                try biometricManager.deleteKey()
                UserDefaults.standard.set(false, forKey: "biometricsEnabled")
                if var meta = vaultMeta {
                    meta.biometricsEnabled = false
                    vaultMeta = meta
                }
            } catch {
                print("Failed to disable biometrics:", error)
            }
        }
    }

    // MARK: - Auto-lock settings

    func updateAutoLockTimeout(seconds: Int) {
        UserDefaults.standard.set(seconds, forKey: "autoLockTimeoutSeconds")
        if var meta = vaultMeta {
            meta.autoLockTimeoutSeconds = seconds
            vaultMeta = meta
        }
    }

    // MARK: - Change master password
    
    func changePassword(currentPassword: String, newPassword: String) throws {
        // Must be unlocked and have a key + store
        guard mode == .unlocked else {
            throw NSError(domain: "VaultError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Vault must be unlocked to change password"])
        }
        guard let store = journalStore, let existingKey = currentKey else {
            throw NSError(domain: "VaultError", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Vault not initialised"])
        }
        
        // 1. Read header from the single vault file
        let (header, _) = try VaultFile.read(from: vaultURL)
        
        guard let saltData = Data(base64Encoded: header.saltBase64) else {
            throw NSError(domain: "VaultError", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid salt in vault header"])
        }
        
        // 2. Derive key from CURRENT password and verify it matches the in-memory key
        let currentKeyData = try PBKDF2.deriveKey(
            password: currentPassword,
            salt: saltData,
            iterations: header.iterations,
            keyLength: 32
        )
        
        // Compare derived key with existingKey
        let existingData = existingKey.withUnsafeBytes { Data($0) }
        guard existingData == currentKeyData else {
            throw NSError(domain: "VaultError", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "Current password is incorrect"])
        }
        
        // 3. Derive NEW key from new password + fresh salt
        let newSalt = try RandomBytes.generate(count: 32)
        let newIterations = header.iterations  // keep same iteration count for this vault
        let newKeyData = try PBKDF2.deriveKey(
            password: newPassword,
            salt: newSalt,
            iterations: newIterations,
            keyLength: 32
        )
        let newKey = SymmetricKey(data: newKeyData)
        
        // 4. Re-encrypt existing entries with the NEW key into a NEW vault file content
        let entriesData = try JSONEncoder().encode(store.entries)
        let crypto = CryptoManager(key: newKey)
        let newCiphertext = try crypto.encrypt(entriesData)
        
        var newHeader = header
        newHeader.saltBase64 = newSalt.base64EncodedString()
        // schemaVersion and iterations stay as-is (unless you deliberately bump them)
        
        try VaultFile.write(to: vaultURL, header: newHeader, ciphertext: newCiphertext)
        
        // 5. Update in-memory state: key, store, vaultMeta mirror
        self.currentKey = newKey
        
        // Recreate the store so future saves use the new key/header
        let newStore = try JournalStore(unlockingWith: newKey, vaultURL: vaultURL)
        self.journalStore = newStore
        
        if var meta = vaultMeta {
            meta.saltBase64 = newHeader.saltBase64
            meta.iterations = newHeader.iterations
            meta.schemaVersion = newHeader.schemaVersion
            self.vaultMeta = meta
        } else {
            // Rebuild a minimal meta if you want
            self.vaultMeta = VaultMeta(
                saltBase64: newHeader.saltBase64,
                iterations: newHeader.iterations,
                biometricsEnabled: false,
                autoLockTimeoutSeconds: 5 * 60,
                schemaVersion: newHeader.schemaVersion
            )
        }
        
        // 6. If biometrics are enabled, refresh the cached key in Keychain
        if vaultMeta?.biometricsEnabled ?? false {
            do {
                try biometricManager.storeKey(newKey)
            } catch {
                print("Warning: failed to update biometric key after password change:", error)
            }
        }
    }
    
    /// Force-set a new master password while the vault is already unlocked.
    /// This does NOT verify the old password. Use only if you are already in
    /// (e.g. via biometrics) and the password path is broken.
    func forceSetNewMasterPassword(newPassword: String) throws {
        // Must already be unlocked
        guard mode == .unlocked else {
            throw NSError(domain: "VaultError", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "Vault must be unlocked to reset password."])
        }
        guard let store = journalStore else {
            throw NSError(domain: "VaultError", code: -11,
                          userInfo: [NSLocalizedDescriptionKey: "Vault not initialised."])
        }
        
        // 1) Read current header from the single vault file
        let (header, _) = try VaultFile.read(from: vaultURL)
        
        // 2) Generate new salt and derive new key from the NEW password
        let newSalt = try RandomBytes.generate(count: 32)
        let newIterations = header.iterations // keep same KDF cost for this vault
        
        let newKeyData = try PBKDF2.deriveKey(
            password: newPassword,
            salt: newSalt,
            iterations: newIterations,
            keyLength: 32
        )
        let newKey = SymmetricKey(data: newKeyData)
        
        // 3) Re-encrypt current in-memory entries with the new key
        let entriesData = try JSONEncoder().encode(store.entries)
        let crypto = CryptoManager(key: newKey)
        let newCiphertext = try crypto.encrypt(entriesData)
        
        // 4) Write updated header + ciphertext to the vault file
        var newHeader = header
        newHeader.saltBase64 = newSalt.base64EncodedString()
        // schemaVersion and iterations stay the same
        
        try VaultFile.write(to: vaultURL, header: newHeader, ciphertext: newCiphertext)
        
        // 5) Update in-memory key + store
        self.currentKey = newKey
        
        let newStore = try JournalStore(unlockingWith: newKey, vaultURL: vaultURL)
        self.journalStore = newStore
        
        // 6) Update vaultMeta mirror (if you still use it for prefs)
        if var meta = vaultMeta {
            meta.saltBase64 = newHeader.saltBase64
            meta.iterations = newHeader.iterations
            meta.schemaVersion = newHeader.schemaVersion
            self.vaultMeta = meta
        } else {
            self.vaultMeta = VaultMeta(
                saltBase64: newHeader.saltBase64,
                iterations: newHeader.iterations,
                biometricsEnabled: false,
                autoLockTimeoutSeconds: 5 * 60,
                schemaVersion: newHeader.schemaVersion
            )
        }
        
        // 7) If biometrics are enabled, refresh cached key in Keychain
        if vaultMeta?.biometricsEnabled ?? false {
            do {
                try biometricManager.storeKey(newKey)
            } catch {
                print("Warning: failed to refresh biometric key after force password reset:", error)
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
    
    private var vaultURL: URL {
        baseDir.appendingPathComponent("Diary.vault")
    }
}

import Combine
import Foundation
import CryptoKit
import UniformTypeIdentifiers
// BackupManager is separate

struct VaultInfo: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var lastOpened: Date?
}

struct VaultsIndex: Codable {
    var vaults: [VaultInfo]
}

protocol BiometricKeychainManaging {
    func storeKey(_ key: SymmetricKey) throws
    func loadKeyWithBiometrics(
        completion: @escaping (Result<SymmetricKey, Swift.Error>) -> Void
    )
    func deleteKey() throws
}

@MainActor
final class DiaryAppState: ObservableObject {
    enum Mode {
        case initializing
        case needsSetup
        case locked
        case unlocked
    }
    
    @Published var mode: Mode = .initializing

    @Published var vaults: [VaultInfo] = []
    @Published var selectedVaultID: UUID?
    
    // Per-selected-vault computed helpers
    var selectedVaultURL: URL? {
        guard let id = selectedVaultID else { return nil }
        return vaultURL(for: id)
    }
    
    @Published var vaultMeta: VaultMeta?
    @Published var journalStore: JournalStore?
    @Published var lastActivity: Date? = nil
    
    private(set) var currentKey: SymmetricKey?
    
    private let fileManager = FileManager.default
    private let baseDir: URL
    
    private var vaultsDir: URL { baseDir.appendingPathComponent("Vaults", isDirectory: true) }
    private var indexURL: URL { baseDir.appendingPathComponent("VaultsIndex.json") }
    
    private let biometricManager: BiometricKeychainManaging
    private lazy var backupManager = BackupManager(appSupportBase: baseDir)
    
    private var saveWorkItem: DispatchWorkItem?
    
    // MARK: - Designated init
    
    init(baseDir: URL, biometricManager: BiometricKeychainManaging) {
        self.baseDir = baseDir
        self.biometricManager = biometricManager
    }
    
    // MARK: - Convenience init for the real app
    
    convenience init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("SimpleDiary", isDirectory: true)
        
        if !fm.fileExists(atPath: appSupport.path) {
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        
        let vaults = appSupport.appendingPathComponent("Vaults", isDirectory: true)
        if !fm.fileExists(atPath: vaults.path) {
            try? fm.createDirectory(at: vaults, withIntermediateDirectories: true)
        }
        
        self.init(
            baseDir: appSupport,
            biometricManager: BiometricKeychainManager()
        )
    }
    
    // MARK: - Vaults index helpers
    
    private func udKey(_ key: String) -> String {
        if let id = selectedVaultID { return "\(key)_\(id.uuidString)" }
        return key
    }
    
    private func loadVaultsIndex() {
        do {
            if fileManager.fileExists(atPath: indexURL.path) {
                let data = try Data(contentsOf: indexURL)
                let idx = try JSONDecoder().decode(VaultsIndex.self, from: data)
                self.vaults = idx.vaults
            } else {
                self.vaults = []
            }
        } catch {
            print("Failed to load vaults index:", error)
            self.vaults = []
        }
    }
    
    private func saveVaultsIndex() {
        do {
            let data = try JSONEncoder().encode(VaultsIndex(vaults: vaults))
            try data.write(to: indexURL, options: [.atomic])
        } catch {
            print("Failed to save vaults index:", error)
        }
    }
    
    private func vaultURL(for id: UUID) -> URL {
        vaultsDir.appendingPathComponent("\(id.uuidString).vault")
    }
    
    // MARK: - Private helper for biometric label
    
    private func biometricLabelForSelectedVault() -> String? {
        guard let id = selectedVaultID else { return nil }
        return "biometricKey_\(id.uuidString)"
    }
    
    // MARK: - Vault lifecycle
    
    func initialize() async {
        // Create vaults directory
        do {
            try fileManager.createDirectory(at: vaultsDir, withIntermediateDirectories: true)
        } catch {}
        
        // One-time migration for legacy single vault
        let legacyURL = baseDir.appendingPathComponent("Diary.vault")
        if fileManager.fileExists(atPath: legacyURL.path) {
            // Only migrate if we have no indexed vaults yet
            loadVaultsIndex()
            if vaults.isEmpty {
                let id = UUID()
                let newURL = vaultURL(for: id)
                do {
                    try fileManager.createDirectory(at: vaultsDir, withIntermediateDirectories: true)
                    try fileManager.moveItem(at: legacyURL, to: newURL)
                    let name = "Imported Vault"
                    let info = VaultInfo(id: id, name: name, lastOpened: nil)
                    vaults = [info]
                    saveVaultsIndex()
                    selectedVaultID = id
                } catch {
                    print("Migration failed:", error)
                }
            }
        }
        
        // Load or create index
        loadVaultsIndex()
        
        // Auto-select last opened vault if none selected
        if selectedVaultID == nil {
            selectedVaultID = vaults.sorted { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }.first?.id
        }
        
        guard let url = selectedVaultURL else {
            // No vaults exist yet
            self.mode = .needsSetup
            return
        }
        
        if fileManager.fileExists(atPath: url.path) {
            do {
                let (header, _) = try VaultFile.read(from: url)
                let biometricsEnabled = UserDefaults.standard.bool(forKey: self.udKey("biometricsEnabled"))
                let autoLock = UserDefaults.standard.integer(forKey: self.udKey("autoLockTimeoutSeconds"))
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
    
    // MARK: - Create / Select / Rename / Delete vaults
    
    func createVault(named name: String, password: String) {
        do {
            try fileManager.createDirectory(at: vaultsDir, withIntermediateDirectories: true)
            let id = UUID()
            let url = vaultURL(for: id)
            // KDF params
            let salt = try RandomBytes.generate(count: 32)
            let iterations = 100_000
            let keyData = try PBKDF2.deriveKey(password: password, salt: salt, iterations: iterations, keyLength: 32)
            let key = SymmetricKey(data: keyData)
            let entries: [JournalEntry] = []
            let json = try JSONEncoder().encode(entries)
            let crypto = CryptoManager(key: key)
            let ciphertext = try crypto.encrypt(json)
            let header = VaultHeader(schemaVersion: 1, saltBase64: salt.base64EncodedString(), iterations: iterations)
            try VaultFile.write(to: url, header: header, ciphertext: ciphertext)
            let info = VaultInfo(id: id, name: name, lastOpened: Date())
            vaults.append(info)
            saveVaultsIndex()
            selectedVaultID = id
            self.currentKey = key
            self.vaultMeta = VaultMeta(saltBase64: header.saltBase64, iterations: header.iterations, biometricsEnabled: false, autoLockTimeoutSeconds: 5*60, schemaVersion: header.schemaVersion)
            let store = JournalStore(key: key, vaultURL: url, header: header)
            store.entries = entries
            self.journalStore = store
            self.mode = .unlocked
            self.noteActivity()
        } catch {
            print("Failed to create vault:", error)
            self.mode = .needsSetup
        }
    }
    
    func selectVault(_ id: UUID) {
        lock()
        selectedVaultID = id
        // Load header to set state to locked
        do {
            let url = vaultURL(for: id)
            let (header, _) = try VaultFile.read(from: url)
            let biometricsEnabled = UserDefaults.standard.bool(forKey: self.udKey("biometricsEnabled"))
            let autoLock = UserDefaults.standard.integer(forKey: self.udKey("autoLockTimeoutSeconds"))
            let timeout = autoLock > 0 ? autoLock : (5 * 60)
            self.vaultMeta = VaultMeta(saltBase64: header.saltBase64, iterations: header.iterations, biometricsEnabled: biometricsEnabled, autoLockTimeoutSeconds: timeout, schemaVersion: header.schemaVersion)
            self.mode = .locked
        } catch {
            print("Failed to select vault:", error)
            self.mode = .needsSetup
        }
    }
    
    func renameVault(_ id: UUID, to newName: String) {
        if let idx = vaults.firstIndex(where: { $0.id == id }) {
            vaults[idx].name = newName
            saveVaultsIndex()
        }
    }
    
    func deleteVault(_ id: UUID) {
        let url = vaultURL(for: id)
        do { try fileManager.removeItem(at: url) } catch { print("Failed to delete vault file:", error) }
        vaults.removeAll { $0.id == id }
        saveVaultsIndex()
        if selectedVaultID == id {
            selectedVaultID = nil
            journalStore = nil
            currentKey = nil
            vaultMeta = nil
            mode = .needsSetup
        }
    }
    
    // MARK: - Setup
    
    func setupVault(password: String) {
        if selectedVaultID == nil { createVault(named: "My Vault", password: password); return }
        guard let url = selectedVaultURL else { return }
        do {
            try fileManager.createDirectory(at: vaultsDir, withIntermediateDirectories: true)
            
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
            try VaultFile.write(to: url, header: header, ciphertext: ciphertext)
            
            // In-memory state
            self.currentKey = key
            self.vaultMeta = VaultMeta(
                saltBase64: header.saltBase64,
                iterations: header.iterations,
                biometricsEnabled: false,
                autoLockTimeoutSeconds: 5*60,
                schemaVersion: header.schemaVersion
            )
            
            let store = JournalStore(key: key, vaultURL: url, header: header)
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
        guard let url = selectedVaultURL else { return }
        do {
            let (header, _) = try VaultFile.read(from: url)
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
        guard let label = biometricLabelForSelectedVault() else { return }
        if let manager = biometricManager as? BiometricKeychainManager {
            manager.loadKeyWithBiometrics(label: label) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success(let key):
                        do { try self.completeUnlock(with: key) } catch { print("Biometric unlock failed:", error) }
                    case .failure(let error):
                        print("Biometric key load failed:", error)
                    }
                }
            }
        } else {
            biometricManager.loadKeyWithBiometrics { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success(let key):
                        do { try self.completeUnlock(with: key) } catch { print("Biometric unlock failed:", error) }
                    case .failure(let error):
                        print("Biometric key load failed:", error)
                    }
                }
            }
        }
    }
    
    private func completeUnlock(with key: SymmetricKey) throws {
        guard let url = selectedVaultURL else {
            throw NSError(domain: "VaultError", code: -100,
                          userInfo: [NSLocalizedDescriptionKey: "No vault selected"])
        }
        
        let store = try JournalStore(unlockingWith: key, vaultURL: url)
        
        // Update in-memory meta from header + stored prefs
        let (header, _) = try VaultFile.read(from: url)
        let biometricsEnabled = UserDefaults.standard.bool(forKey: udKey("biometricsEnabled"))
        let autoLock = UserDefaults.standard.integer(forKey: udKey("autoLockTimeoutSeconds"))
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
        
        // Update lastOpened for selected vault and save index
        if let id = selectedVaultID, let idx = vaults.firstIndex(where: { $0.id == id }) {
            vaults[idx].lastOpened = Date()
            saveVaultsIndex()
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
            guard let key = currentKey, let label = biometricLabelForSelectedVault() else { return }
            do {
                if let manager = biometricManager as? BiometricKeychainManager {
                    try manager.storeKey(key, label: label)
                } else {
                    try biometricManager.storeKey(key)
                }
                UserDefaults.standard.set(true, forKey: udKey("biometricsEnabled"))
                if var meta = vaultMeta { meta.biometricsEnabled = true; vaultMeta = meta }
            } catch {
                print("Failed to enable biometrics:", error)
            }
        } else {
            do {
                if let label = biometricLabelForSelectedVault(), let manager = biometricManager as? BiometricKeychainManager {
                    try manager.deleteKey(label: label)
                } else {
                    try biometricManager.deleteKey()
                }
                UserDefaults.standard.set(false, forKey: udKey("biometricsEnabled"))
                if var meta = vaultMeta { meta.biometricsEnabled = false; vaultMeta = meta }
            } catch {
                print("Failed to disable biometrics:", error)
            }
        }
    }
    
    // MARK: - Auto-lock settings
    
    func updateAutoLockTimeout(seconds: Int) {
        UserDefaults.standard.set(seconds, forKey: udKey("autoLockTimeoutSeconds"))
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
        guard let url = selectedVaultURL else {
            throw NSError(domain: "VaultError", code: -101,
                          userInfo: [NSLocalizedDescriptionKey: "No vault selected"])
        }
        
        // 1. Read header from the single vault file
        let (header, _) = try VaultFile.read(from: url)
        
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
        
        try VaultFile.write(to: url, header: newHeader, ciphertext: newCiphertext)
        
        // 5. Update in-memory state: key, store, vaultMeta mirror
        self.currentKey = newKey
        
        // Recreate the store so future saves use the new key/header
        let newStore = try JournalStore(unlockingWith: newKey, vaultURL: url)
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
        guard let url = selectedVaultURL else {
            throw NSError(domain: "VaultError", code: -102,
                          userInfo: [NSLocalizedDescriptionKey: "No vault selected"])
        }
        
        // 1) Read current header from the single vault file
        let (header, _) = try VaultFile.read(from: url)
        
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
        
        try VaultFile.write(to: url, header: newHeader, ciphertext: newCiphertext)
        
        // 5) Update in-memory key + store
        self.currentKey = newKey
        
        let newStore = try JournalStore(unlockingWith: newKey, vaultURL: url)
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
    
    // MARK: - Saving
    
    /// Schedule a debounced save of the current entries.
    func scheduleSave() {
        guard let store = journalStore else { return }
        
        // Any change is activity
        noteActivity()
        
        // Cancel previous pending save
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            // Do the heavy work off the main thread
            DispatchQueue.global(qos: .utility).async {
                store.save()
            }
        }
        
        saveWorkItem = workItem
        
        // Save after 0.7s of no further edits
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }

    /// Export the current app state to iCloud Drive. If vaultID is nil, export all vaults.
    func exportBackupToICloud(vaultID: UUID? = nil) throws -> URL {
        guard FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil else {
            throw NSError(domain: "BackupError", code: -10, userInfo: [NSLocalizedDescriptionKey: "iCloud Drive is unavailable on this device/account."])
        }
        return try backupManager.exportCurrentStateToICloudDrive(vaultID: vaultID)
    }

    /// Import a backup from a given iCloud backup folder URL back into app storage.
    /// - Parameters:
    ///   - backupFolder: URL within the app's iCloud backup directory.
    ///   - replaceExisting: If true, overwrite existing vault files with those from backup.
    func importBackupFromICloud(backupFolder: URL, replaceExisting: Bool) throws {
        try backupManager.importFromICloudBackup(at: backupFolder, replaceExisting: replaceExisting)
        // After import, reload index and adjust selection if needed
        loadVaultsIndex()
        if selectedVaultID != nil, let id = selectedVaultID, !vaults.contains(where: { $0.id == id }) {
            selectedVaultID = vaults.first?.id
        }
    }
    
    func exportBackup(to destinationDirectory: URL) throws -> URL {
        // Ensure the destination is a directory we can write into.
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destinationDirectory.path, isDirectory: &isDir), isDir.boolValue else {
            throw NSError(domain: "BackupError", code: -20, userInfo: [NSLocalizedDescriptionKey: "Destination is not a directory."])
        }
        
        // Export the current app state into the provided destination directory. Export all vaults by default.
        let exportedFolder = try backupManager.exportCurrentState(to: destinationDirectory, vaultID: nil)
        return exportedFolder
    }
}

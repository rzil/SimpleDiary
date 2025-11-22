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
                biometricsEnabled: false
            )
            try saveMeta(meta)
            self.vaultMeta = meta

            let store = try JournalStore(key: key, baseDir: baseDir)
            self.journalStore = store
            self.mode = .unlocked
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
}

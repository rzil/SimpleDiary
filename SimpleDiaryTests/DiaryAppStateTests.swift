import Testing
import Foundation
import CryptoKit
@testable import SimpleDiary

private final class MockBiometricManager: BiometricKeychainManaging {
    var storedKey: SymmetricKey?
    func storeKey(_ key: SymmetricKey) throws { storedKey = key }
    func loadKeyWithBiometrics(completion: @escaping (Result<SymmetricKey, Swift.Error>) -> Void) { completion(.failure(NSError(domain: "test", code: -1))) }
    func deleteKey() throws { storedKey = nil }
}

@Suite("DiaryAppState basic flows")
@MainActor
struct DiaryAppStateTests {
    private func tempBaseDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DiaryAppTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("createVault creates file and unlocks")
    func createVaultUnlocks() async throws {
        let base = try tempBaseDir()
        let app = DiaryAppState(baseDir: base, biometricManager: MockBiometricManager())

        // Precondition
        #expect(app.mode == .initializing)

        app.createVault(named: "Test Vault", password: "secret")

        #expect(app.mode == .unlocked)
        #expect(app.currentKey != nil)
        #expect(app.journalStore != nil)
        #expect(app.selectedVaultID != nil)
        #expect(app.vaults.contains { $0.id == app.selectedVaultID })

        // Verify file exists
        if let id = app.selectedVaultID {
            let url = base.appendingPathComponent("Vaults", isDirectory: true).appendingPathComponent("\(id.uuidString).vault")
            #expect(FileManager.default.fileExists(atPath: url.path))
        } else {
            #expect(Bool(false), "selectedVaultID should not be nil")
        }
    }

    @Test("unlockWithPassword succeeds with correct password")
    func unlockWithPassword() async throws {
        let base = try tempBaseDir()
        let app = DiaryAppState(baseDir: base, biometricManager: MockBiometricManager())

        app.createVault(named: "Test Vault", password: "secret")
        let createdID = try #require(app.selectedVaultID)
        app.lock()
        app.selectVault(createdID)
        #expect(app.mode == .locked)

        app.unlockWithPassword("secret")
        #expect(app.mode == .unlocked)
        #expect(app.currentKey != nil)
        #expect(app.journalStore != nil)
    }
}

import Testing
import Foundation
@testable import SimpleDiary

@MainActor
@Suite("Vaults index round-trip")
struct VaultsIndexTests {
    @Test("Create vault persists to index and reloads")
    func createAndReloadVaultIndex() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        let app = AppState(baseDir: base, biometricManager: StubBiometricManager())
        app.createVault(named: "Test Vault", password: "pw")

        let appReloaded = AppState(baseDir: base, biometricManager: StubBiometricManager())
        await appReloaded.initialize()

        #expect(appReloaded.vaults.contains { $0.name == "Test Vault" })
    }
}


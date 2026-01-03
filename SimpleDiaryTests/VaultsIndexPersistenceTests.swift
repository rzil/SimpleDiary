import Testing
import Foundation
@testable import SimpleDiary

@MainActor
@Suite("Vaults index persistence")
struct VaultsIndexPersistenceTests {
    @Test("Multiple vaults persist and reload")
    func multipleVaultsPersistAndReload() async {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        let app = DiaryAppState(baseDir: base, biometricManager: StubBiometricManager())
        await app.initialize()
        app.createVault(named: "A", password: "pw")
        app.createVault(named: "B", password: "pw")
        app.createVault(named: "C", password: "pw")

        // Reload index
        let appReloaded = DiaryAppState(baseDir: base, biometricManager: StubBiometricManager())
        await appReloaded.initialize()

        let names = Set(appReloaded.vaults.map { $0.name })
        #expect(names == Set(["A", "B", "C"]))
    }
}

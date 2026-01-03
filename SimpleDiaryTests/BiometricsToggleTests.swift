import Testing
import Foundation
import CryptoKit
@testable import SimpleDiary

@MainActor
@Suite("Biometrics toggle")
struct BiometricsToggleTests {
    @Test("Enabling and disabling biometrics updates meta and persists")
    func toggleBiometricsPersists() async {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = DiaryAppState(baseDir: base, biometricManager: StubBiometricManager())
        await app.initialize()
        app.createVault(named: "BIO", password: "pw")
        #expect(app.vaultMeta?.biometricsEnabled == false)

        app.setBiometricsEnabled(true)
        #expect(app.vaultMeta?.biometricsEnabled == true)

        // Reload and verify persistence
        let appReloaded = DiaryAppState(baseDir: base, biometricManager: StubBiometricManager())
        await appReloaded.initialize()
        #expect(appReloaded.vaultMeta?.biometricsEnabled == true)

        // Disable and verify again
        appReloaded.setBiometricsEnabled(false)
        #expect(appReloaded.vaultMeta?.biometricsEnabled == false)

        let appReloaded2 = DiaryAppState(baseDir: base, biometricManager: StubBiometricManager())
        await appReloaded2.initialize()
        #expect(appReloaded2.vaultMeta?.biometricsEnabled == false)
    }
}

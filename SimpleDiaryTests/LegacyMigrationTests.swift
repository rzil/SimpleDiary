import Testing
import Foundation
@testable import SimpleDiary

@MainActor
@Suite("Legacy migration")
struct LegacyMigrationTests {
    @Test("Migrates legacy Diary.vault into new structure when no index exists")
    func migratesLegacyVault() async throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)

        // Place a fake legacy file at base/Diary.vault
        let legacyURL = base.appendingPathComponent("Diary.vault")
        try Data([0x00]).write(to: legacyURL)

        // Initialize should attempt migration only when index is empty
        let app = DiaryAppState(baseDir: base, biometricManager: StubBiometricManager())
        await app.initialize()

        // After migration, either needsSetup or locked depending on header readability; at minimum, index should have one vault
        #expect(app.vaults.count == 1)
        #expect(app.selectedVaultID != nil || app.mode == .needsSetup || app.mode == .locked)

        // The legacy file should have been moved into the Vaults directory
        let vaultsDir = base.appendingPathComponent("Vaults", isDirectory: true)
        let contents = try? fm.contentsOfDirectory(at: vaultsDir, includingPropertiesForKeys: nil)
        #expect((contents?.isEmpty ?? true) == false)
    }
}

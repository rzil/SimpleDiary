import Testing
import Foundation
import CryptoKit
@testable import SimpleDiary

@MainActor
@Suite("JournalStore round-trip")
struct JournalStoreRoundTripTests {
    @Test("Entries persist through save/load")
    func entriesPersist() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = AppState(baseDir: base, biometricManager: StubBiometricManager())
        await app.initialize()
        app.createVault(named: "RT", password: "pw")

        // Add two entries
        guard let store = app.journalStore else { throw NSError(domain: "test", code: -1) }
        let first = store.addEntry()
        let second = store.addEntry()
        #expect(store.entries.first?.id == second.id)
        #expect(store.entries.count == 2)

        // Save is triggered by addEntry(); ensure it's written
        store.save()

        // Reload a new AppState from same base
        let appReloaded = AppState(baseDir: base, biometricManager: StubBiometricManager())
        await appReloaded.initialize()
        // Unlock with the same password
        appReloaded.unlockWithPassword("pw")
        // Allow main-actor tasks to settle
        #expect(appReloaded.journalStore?.entries.count == 2)
        #expect(appReloaded.journalStore?.entries.first?.id == second.id)
        #expect(appReloaded.journalStore?.entries.last?.id == first.id)
    }
}

import Testing
import Foundation
import CryptoKit
@testable import SimpleDiary

@MainActor
@Suite("JournalStore delete entries")
struct JournalStoreDeleteTests {
    @Test("Deleting by offsets removes correct entries and persists")
    func deleteByOffsets() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = DiaryAppState(baseDir: base, biometricManager: StubBiometricManager())
        await app.initialize()
        app.createVault(named: "DEL", password: "pw")

        guard let store = app.journalStore else { throw NSError(domain: "test", code: -1) }
        // Add three entries (most recent at index 0)
        let a = store.addEntry()
        let b = store.addEntry()
        let c = store.addEntry()
        #expect(store.entries.map { $0.id } == [c.id, b.id, a.id])

        // Delete the middle one (current order index 1)
        store.deleteEntries(at: IndexSet(integer: 1))
        #expect(store.entries.map { $0.id } == [c.id, a.id])

        // Save and reload to ensure persistence
        store.save()
        let appReloaded = DiaryAppState(baseDir: base, biometricManager: StubBiometricManager())
        await appReloaded.initialize()
        appReloaded.unlockWithPassword("pw")
        let ids = appReloaded.journalStore?.entries.map { $0.id }
        #expect(ids == [c.id, a.id])
    }
}

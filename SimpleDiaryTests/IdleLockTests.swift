import Testing
import Foundation
@testable import SimpleDiary

@MainActor
@Suite("Idle lock")
struct IdleLockTests {
    @Test("Locks after timeout when idle")
    func locksAfterTimeout() async {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = AppState(baseDir: base, biometricManager: StubBiometricManager())

        // Initialize the app (no vaults yet → needsSetup)
        await app.initialize()
        #expect(app.mode == .needsSetup)

        // Create a vault → app becomes unlocked
        app.createVault(named: "IdleTest", password: "pw")
        #expect(app.mode == .unlocked)

        // Seed a short timeout and simulate idle
        app.vaultMeta?.autoLockTimeoutSeconds = 1
        app.noteActivity()
        app.lastActivity = Date().addingTimeInterval(-5)

        // Now the idle lock should transition to locked
        app.checkIdleLock()
        #expect(app.mode == .locked)
    }
}


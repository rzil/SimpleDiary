import Testing
import Foundation
import CryptoKit
@testable import SimpleDiary

@MainActor
@Suite("Password change flows")
struct PasswordChangeFlowTests {
    @Test("changePassword updates key and rejects old password")
    func changePasswordFlow() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = AppState(baseDir: base, biometricManager: StubBiometricManager())
        await app.initialize()

        // Create vault and unlock
        app.createVault(named: "PWT", password: "oldpw")
        #expect(app.mode == .unlocked)

        // Change to new password
        try app.changePassword(currentPassword: "oldpw", newPassword: "newpw")

        // Lock and verify old password fails, new succeeds
        app.lock()
        #expect(app.mode == .locked)

        app.unlockWithPassword("oldpw")
        // Should remain locked due to wrong password
        #expect(app.mode == .locked)

        app.unlockWithPassword("newpw")
        // Should unlock with the new password
        #expect(app.mode == .unlocked)
    }

    @Test("forceSetNewMasterPassword updates key while unlocked")
    func forceSetNewMasterPasswordFlow() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = AppState(baseDir: base, biometricManager: StubBiometricManager())
        await app.initialize()
        app.createVault(named: "PWT2", password: "pw1")
        #expect(app.mode == .unlocked)

        try app.forceSetNewMasterPassword(newPassword: "pw2")
        // Still unlocked after force reset
        #expect(app.mode == .unlocked)

        // Lock and verify new password unlocks
        app.lock()
        #expect(app.mode == .locked)
        app.unlockWithPassword("pw2")
        #expect(app.mode == .unlocked)
    }
}

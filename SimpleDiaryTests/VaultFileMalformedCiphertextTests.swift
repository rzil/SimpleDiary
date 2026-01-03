import Testing
import Foundation
import CryptoKit
@testable import SimpleDiary

@MainActor
@Suite("Malformed ciphertext handling")
struct VaultFileMalformedCiphertextTests {
    @Test("Decrypting invalid ciphertext fails during unlock")
    func invalidCiphertextDuringUnlock() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = AppState(baseDir: base, biometricManager: StubBiometricManager())
        await app.initialize()

        // Create a valid vault first
        app.createVault(named: "Bad", password: "pw")
        #expect(app.mode == .unlocked)

        // Corrupt the vault file by overwriting ciphertext after creation
        guard let url = app.selectedVaultURL else { throw NSError(domain: "test", code: -1) }
        let (header, _) = try VaultFile.read(from: url)
        // Write same header but garbage ciphertext
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])
        try VaultFile.write(to: url, header: header, ciphertext: garbage)

        // Lock then try to unlock with correct password; should fail
        app.lock()
        #expect(app.mode == .locked)
        app.unlockWithPassword("pw")
        // Expect to remain locked due to decryption/decoding failure
        #expect(app.mode == .locked)
    }
}

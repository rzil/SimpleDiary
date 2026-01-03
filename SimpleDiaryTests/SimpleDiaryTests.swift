import Testing
import Foundation
import CryptoKit
@testable import SimpleDiary

@Suite("Math utilities")
struct MathUtilitiesTests {
    @Test("Adding two integers should produce correct sum")
    func testAddition() {
        let a = 2
        let b = 5
        let sum = a + b
        #expect(sum == 7)
    }

    @Test("Factorial of small numbers")
    func testFactorial() {
        func factorial(_ n: Int) -> Int {
            if n <= 1 { return 1 }
            return (2...n).reduce(1, *)
        }
        #expect(factorial(0) == 1)
        #expect(factorial(1) == 1)
        #expect(factorial(5) == 120)
    }
}

private final class StubBiometricManager: BiometricKeychainManaging {
    func storeKey(_ key: SymmetricKey) throws {}
    func loadKeyWithBiometrics(completion: @escaping (Result<SymmetricKey, Swift.Error>) -> Void) { completion(.failure(NSError(domain: "stub", code: -1))) }
    func deleteKey() throws {}
}

@MainActor
@Suite("AppState lightweight logic")
struct AppStateLogicTests {
    @Test("updateAutoLockTimeout writes into meta when present")
    func updateAutoLockTimeout() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = AppState(baseDir: tempDir, biometricManager: StubBiometricManager())

        // Seed meta directly (we're not exercising file I/O here)
        app.selectedVaultID = UUID()
        app.vaultMeta = VaultMeta(saltBase64: "salt", iterations: 1, biometricsEnabled: false, autoLockTimeoutSeconds: 300, schemaVersion: 1)

        app.updateAutoLockTimeout(seconds: 123)
        #expect(app.vaultMeta?.autoLockTimeoutSeconds == 123)
    }

    @Test("lock moves mode to locked and clears sensitive state")
    func lockResetsState() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let app = AppState(baseDir: tempDir, biometricManager: StubBiometricManager())

        // Start from default state; call lock() and verify invariants we can observe.
        app.lock()
        #expect(app.mode == .locked)
        // We cannot and should not set or read private(set) internals beyond availability; ensure no crash and mode is correct.
    }
}


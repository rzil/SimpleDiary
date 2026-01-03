import Testing
import Foundation
import CryptoKit
@testable import SimpleDiary

@Suite("PBKDF2 tests")
struct PBKDF2Tests {
    @Test("Deterministic vector matches known output")
    func deterministicVector() throws {
        // RFC 6070 style vector adapted for HMAC-SHA256
        // password = "password", salt = "salt", iterations = 1, dkLen = 32
        let password = "password"
        let salt = Data("salt".utf8)
        let key = try PBKDF2.deriveKey(password: password, salt: salt, iterations: 1, keyLength: 32)
        // Expected derived key for PBKDF2-HMAC-SHA256 with these params
        // Precomputed with a reference implementation
        let expectedHex = "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
        #expect(key.map { String(format: "%02x", $0) }.joined() == expectedHex)
    }

    @Test("Preconditions and errors")
    func edgeCases() throws {
        // iterations > 0 should throw invalidIterations
        do {
            _ = try PBKDF2.deriveKey(password: "pw", salt: Data(), iterations: 0, keyLength: 32)
            #expect(Bool(false), "Expected invalidIterations error for iterations == 0")
        } catch PBKDF2.Error.invalidIterations {
            // expected
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Known vectors from RFC 6070 adapted to HMAC-SHA256")
    func knownVectors() throws {
        struct TestVector {
            let password: String
            let salt: Data
            let iterations: Int
            let keyLength: Int
            let expectedHex: String
        }

        let vectors = [
            TestVector(password: "password", salt: Data("salt".utf8), iterations: 2, keyLength: 32,
                       expectedHex: "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"),
            TestVector(password: "passwordPASSWORDpassword", salt: Data("saltSALTsaltSALTsaltSALTsaltSALTsalt".utf8), iterations: 4096, keyLength: 40,
                       expectedHex: "348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9"),
            TestVector(password: "pass\0word", salt: Data("sa\0lt".utf8), iterations: 4096, keyLength: 16,
                       expectedHex: "89b69d0516f829893c696226650a8687")
        ]

        for vector in vectors {
            let derivedKey = try PBKDF2.deriveKey(password: vector.password, salt: vector.salt, iterations: vector.iterations, keyLength: vector.keyLength)
            let derivedHex = derivedKey.map { String(format: "%02x", $0) }.joined()
            #expect(derivedHex == vector.expectedHex, "Failed for password: \(vector.password), salt: \(vector.salt)")
        }
    }

    @Test("Edge case parameters")
    func edgeCaseParameters() throws {
        // Minimum key length 1
        let key1 = try PBKDF2.deriveKey(password: "pw", salt: Data("salt".utf8), iterations: 1, keyLength: 1)
        #expect(key1.count == 1)

        // Very large key length (e.g. 64 bytes)
        let key64 = try PBKDF2.deriveKey(password: "pw", salt: Data("salt".utf8), iterations: 1000, keyLength: 64)
        #expect(key64.count == 64)

        // Empty password
        let keyEmptyPassword = try PBKDF2.deriveKey(password: "", salt: Data("salt".utf8), iterations: 1000, keyLength: 32)
        #expect(keyEmptyPassword.count == 32)

        // Empty salt
        let keyEmptySalt = try PBKDF2.deriveKey(password: "pw", salt: Data(), iterations: 1000, keyLength: 32)
        #expect(keyEmptySalt.count == 32)
    }

    @Test("Encryption round-trip with PBKDF2-derived key (AES-GCM)")
    func encryptionRoundTrip() throws {
        // Given
        let password = "correct horse battery staple"
        let salt = Data("fixed-testsalt-01".utf8) // deterministic test salt
        let iterations = 10_000
        let keyLength = 32 // 256-bit key for AES-GCM
        let plaintext = Data("Secret diary entry contents".utf8)
        // Derive key
        let keyData = try PBKDF2.deriveKey(password: password, salt: salt, iterations: iterations, keyLength: keyLength)
        let symKey = SymmetricKey(data: keyData)

        // Encrypt
        let sealed = try AES.GCM.seal(plaintext, using: symKey)
        let combined = try #require(sealed.combined)

        // Decrypt
        let opened = try AES.GCM.SealedBox(combined: combined)
        let decrypted = try AES.GCM.open(opened, using: symKey)

        // Then
        #expect(decrypted == plaintext)
    }

    @Test("Wrong password should fail decryption (AES-GCM)")
    func wrongPasswordDecryptionFails() throws {
        // Given
        let correctPassword = "correct horse battery staple"
        let wrongPassword = "correct horse battery stapler" // subtle difference
        let salt = Data("fixed-testsalt-02".utf8)
        let iterations = 10_000
        let keyLength = 32
        let plaintext = Data("Another secret entry".utf8)

        // Derive correct key and encrypt
        let correctKeyData = try PBKDF2.deriveKey(password: correctPassword, salt: salt, iterations: iterations, keyLength: keyLength)
        let correctKey = SymmetricKey(data: correctKeyData)
        let sealed = try AES.GCM.seal(plaintext, using: correctKey)
        let combined = try #require(sealed.combined)

        // Derive wrong key
        let wrongKeyData = try PBKDF2.deriveKey(password: wrongPassword, salt: salt, iterations: iterations, keyLength: keyLength)
        let wrongKey = SymmetricKey(data: wrongKeyData)

        // When/Then: opening with the wrong key should throw
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            _ = try AES.GCM.open(sealedBox, using: wrongKey)
            #expect(Bool(false), "Decryption with wrong password unexpectedly succeeded")
        } catch {
            // Expected: authentication should fail
            #expect(true)
        }
    }

    @Test("Unicode password and binary salt produce stable key length")
    func unicodePasswordBinarySalt() throws {
        let password = "pässwörd🔒"
        var salt = Data(count: 16)
        // Deterministic binary salt: 0x00, 0x01, ... 0x0F
        salt.withUnsafeMutableBytes { buf in
            guard let base = buf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<buf.count { base[i] = UInt8(i & 0xFF) }
        }
        let key = try PBKDF2.deriveKey(password: password, salt: salt, iterations: 4096, keyLength: 32)
        #expect(key.count == 32)
    }
    @Test("Invalid parameters: negative iterations should throw")
    func negativeIterationsThrows() throws {
        do {
            _ = try PBKDF2.deriveKey(password: "pw", salt: Data([0x00]), iterations: -1, keyLength: 32)
            #expect(Bool(false), "Expected error for negative iterations")
        } catch PBKDF2.Error.invalidIterations {
            #expect(true)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Invalid parameters: zero or negative key length should throw if enforced")
    func invalidKeyLengthThrowsIfEnforced() throws {
        // If your PBKDF2 implementation enforces keyLength > 0, this should throw.
        // If it doesn't, this test will assert the returned length instead.
        var threw = false
        do {
            _ = try PBKDF2.deriveKey(password: "pw", salt: Data([0xAA]), iterations: 1_000, keyLength: 0)
        } catch {
            threw = true
        }
        if threw {
            #expect(true)
        } else {
            // Fallback behavior: if no throw, ensure implementation returns empty key for length 0
            let key = try PBKDF2.deriveKey(password: "pw", salt: Data([0xAA]), iterations: 1_000, keyLength: 0)
            #expect(key.count == 0)
        }
    }

    @Test("Long inputs: large password and salt")
    func longInputs() throws {
        // 4KB password of repeating pattern
        let password = String(repeating: "p@$$w0rd🚀", count: 400) // ~4KB UTF-8
        // 512-byte binary salt
        var salt = Data(count: 512)
        salt.withUnsafeMutableBytes { buf in
            guard let base = buf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<buf.count { base[i] = UInt8((i * 31) & 0xFF) }
        }
        let key = try PBKDF2.deriveKey(password: password, salt: salt, iterations: 2_000, keyLength: 48)
        #expect(key.count == 48)
    }

    @Test("Maximum derived key length behavior (HMAC-SHA256)")
    func maximumKeyLengthBehavior() throws {
        let password = "pw"
        let salt = Data("max-len-salt".utf8)
        let iterations = 1_000
        let maxLen = 32 * 255 // 8160 bytes for HMAC-SHA256
        // Request exactly the theoretical maximum
        let keyMax = try PBKDF2.deriveKey(password: password, salt: salt, iterations: iterations, keyLength: maxLen)
        #expect(keyMax.count == maxLen)

        // Request above the maximum — expect a throw if enforced, else at least ensure length matches request
        var threw = false
        do {
            _ = try PBKDF2.deriveKey(password: password, salt: salt, iterations: iterations, keyLength: maxLen + 1)
        } catch {
            threw = true
        }
        if threw {
            #expect(true)
        } else {
            let key = try PBKDF2.deriveKey(password: password, salt: salt, iterations: iterations, keyLength: maxLen + 1)
            #expect(key.count == maxLen + 1)
        }
    }

    @Test("Different iteration counts must yield different keys")
    func differentIterationsYieldDifferentKeys() throws {
        let password = "same-password"
        let salt = Data("same-salt".utf8)
        let keyLen = 32
        let key1 = try PBKDF2.deriveKey(password: password, salt: salt, iterations: 1_000, keyLength: keyLen)
        let key2 = try PBKDF2.deriveKey(password: password, salt: salt, iterations: 2_000, keyLength: keyLen)
        #expect(key1 != key2)
    }

    @Test("Different salts must yield different keys")
    func differentSaltsYieldDifferentKeys() throws {
        let password = "same-password"
        let salt1 = Data("salt-A".utf8)
        let salt2 = Data("salt-B".utf8)
        let keyLen = 32
        let keyA = try PBKDF2.deriveKey(password: password, salt: salt1, iterations: 1_000, keyLength: keyLen)
        let keyB = try PBKDF2.deriveKey(password: password, salt: salt2, iterations: 1_000, keyLength: keyLen)
        #expect(keyA != keyB)
    }

    @Test("Same inputs must yield identical keys (determinism)")
    func determinismSameInputs() throws {
        let password = "deterministic"
        let salt = Data("det-salt".utf8)
        let iterations = 4096
        let keyLen = 32
        let k1 = try PBKDF2.deriveKey(password: password, salt: salt, iterations: iterations, keyLength: keyLen)
        let k2 = try PBKDF2.deriveKey(password: password, salt: salt, iterations: iterations, keyLength: keyLen)
        #expect(k1 == k2)
    }
}


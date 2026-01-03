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
}



import Foundation
import CryptoKit

/// Minimal PBKDF2-HMAC-SHA256 implementation for deriving a key from a password.
/// Note: for a real product consider using a well-reviewed KDF implementation or Argon2.
enum PBKDF2 {
    enum Error: Swift.Error {
        case derivedKeyTooLong
    }
    
    static func deriveKey(password: String, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
        let passwordData = Data(password.utf8)
        return try deriveKey(passwordData: passwordData, salt: salt, iterations: iterations, keyLength: keyLength)
    }
    
    static func deriveKey(passwordData: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
        let hLen = Int(SHA256.Digest.byteCount)
        let l = Int(ceil(Double(keyLength) / Double(hLen)))
        let r = keyLength - (l - 1) * hLen
        if l > Int(UInt32.max) {
            throw Error.derivedKeyTooLong
        }
        
        var derived = Data()
        derived.reserveCapacity(keyLength)
        
        for i in 1...l {
            let block = try F(password: passwordData, salt: salt, iterations: iterations, blockIndex: UInt32(i))
            if i == l {
                derived.append(block.prefix(r))
            } else {
                derived.append(block)
            }
        }
        return derived
    }
    
    private static func F(password: Data, salt: Data, iterations: Int, blockIndex: UInt32) throws -> Data {
        var iBE = blockIndex.bigEndian
        let iData = Data(bytes: &iBE, count: MemoryLayout<UInt32>.size)
        
        let key = SymmetricKey(data: password)
        var u = Data(HMAC<SHA256>.authenticationCode(for: salt + iData, using: key))
        var t = u
        
        if iterations > 1 {
            for _ in 2...iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                t = xorData(t, u)
            }
        }
        
        return t
    }
    
    private static func xorData(_ a: Data, _ b: Data) -> Data {
        let count = min(a.count, b.count)
        var result = Data(count: count)
        
        for i in 0..<count {
            let byte = a[i] ^ b[i]
            result[i] = byte
        }
        return result
    }
}

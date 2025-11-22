
import Foundation
import CryptoKit

/// Wraps CryptoKit AES.GCM operations.
final class CryptoManager {
    private let key: SymmetricKey

    init(key: SymmetricKey) {
        self.key = key
    }

    func encrypt(_ plaintext: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw NSError(domain: "CryptoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to produce combined AES-GCM box"])
        }
        return combined
    }

    func decrypt(_ combined: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }
}

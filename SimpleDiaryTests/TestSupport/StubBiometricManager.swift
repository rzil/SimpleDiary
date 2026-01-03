import Foundation
import CryptoKit
@testable import SimpleDiary

final class StubBiometricManager: BiometricKeychainManaging {
    func storeKey(_ key: SymmetricKey) throws {}
    func loadKeyWithBiometrics(completion: @escaping (Result<SymmetricKey, Swift.Error>) -> Void) {
        completion(.failure(NSError(domain: "stub", code: -1)))
    }
    func deleteKey() throws {}
}

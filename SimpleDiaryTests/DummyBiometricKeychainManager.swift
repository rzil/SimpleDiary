//
//  DummyBiometricKeychainManager.swift
//  SimpleDiaryTests
//
//  Created by Ruben Zilibowitz on 23/11/2025.
//

import Foundation
import CryptoKit
@testable import SimpleDiary

final class DummyBiometricKeychainManager: BiometricKeychainManaging {
    func storeKey(_ key: SymmetricKey) throws {
        // no-op
    }
    
    func loadKeyWithBiometrics(
        completion: @escaping (Result<SymmetricKey, Swift.Error>) -> Void
    ) {
        // For tests that don't care about biometrics, just fail or call completion with keyNotFound
        completion(.failure(NSError(
            domain: "DummyBiometricKeychainManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Biometrics not available in tests"]
        )))
    }
    
    func deleteKey() throws {
        // no-op
    }
}

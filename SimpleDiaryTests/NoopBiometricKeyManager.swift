//
//  DummyBiometricKeychainManager.swift
//  SimpleDiaryTests
//
//  Created by Ruben Zilibowitz on 23/11/2025.
//

import Foundation
import CryptoKit
@testable import SimpleDiary

final class NoopBiometricKeyManager: BiometricKeychainManaging {
    func storeKey(_ key: SymmetricKey) throws {}
    func loadKeyWithBiometrics(completion: @escaping (Result<SymmetricKey, Error>) -> Void) {
        completion(.failure(NSError(domain: "Test", code: -1)))
    }
    func deleteKey() throws {}
}

//
//  JournalStoreTests.swift
//  SimpleDiaryTests
//
//  Created by Ruben Zilibowitz on 23/11/2025.
//

import XCTest
@testable import SimpleDiary
import CryptoKit

final class JournalStoreTests: XCTestCase {

    private func makeTempVaultURL() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir.appendingPathComponent("Diary.vault")
    }

    func testJournalStoreSaveAndReloadRoundTrip() throws {
        let vaultURL = try makeTempVaultURL()

        // KDF setup
        let salt = try RandomBytes.generate(count: 32)
        let iterations = 100_000
        let keyData = try PBKDF2.deriveKey(
            password: "test-password",
            salt: salt,
            iterations: iterations,
            keyLength: 32
        )
        let key = SymmetricKey(data: keyData)

        let header = VaultHeader(
            schemaVersion: 1,
            saltBase64: salt.base64EncodedString(),
            iterations: iterations
        )

        // Initial store + save
        let store = JournalStore(key: key, vaultURL: vaultURL, header: header)
        store.entries = [
            JournalEntry(title: "First", body: "One"),
            JournalEntry(title: "Second", body: "Two")
        ]
        store.save()

        // Reload using unlocking initializer
        let reloaded = try JournalStore(unlockingWith: key, vaultURL: vaultURL)
        XCTAssertEqual(reloaded.entries.count, 2)
        XCTAssertEqual(reloaded.entries[0].title, "First")
        XCTAssertEqual(reloaded.entries[1].body, "Two")
    }

    func testWrongKeyFailsToDecrypt() throws {
        let vaultURL = try makeTempVaultURL()

        let salt = try RandomBytes.generate(count: 32)
        let iterations = 100_000

        // Correct key
        let rightKeyData = try PBKDF2.deriveKey(
            password: "correct-password",
            salt: salt,
            iterations: iterations,
            keyLength: 32
        )
        let rightKey = SymmetricKey(data: rightKeyData)

        let header = VaultHeader(
            schemaVersion: 1,
            saltBase64: salt.base64EncodedString(),
            iterations: iterations
        )

        let store = JournalStore(key: rightKey, vaultURL: vaultURL, header: header)
        store.entries = [JournalEntry(title: "Secret", body: "Top secret")]
        store.save()

        // Wrong key
        let wrongKeyData = try PBKDF2.deriveKey(
            password: "wrong-password",
            salt: salt,
            iterations: iterations,
            keyLength: 32
        )
        let wrongKey = SymmetricKey(data: wrongKeyData)

        XCTAssertThrowsError(try JournalStore(unlockingWith: wrongKey, vaultURL: vaultURL)) { error in
            // Ideally, you check it's a CryptoKit authenticationFailure, but even generic throw is fine
            // print("Got error:", error)
        }
    }
}

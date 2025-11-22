//
//  SimpleDiaryTests.swift
//  SimpleDiaryTests
//
//  Created by Ruben Zilibowitz on 22/11/2025.
//

import XCTest
@testable import SimpleDiary

@MainActor
final class AppStateTests: XCTestCase {
    
    private func makeTempDir() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func makeTempAppState(in dir: URL) -> AppState {
        AppState(baseDir: dir, biometricManager: NoopBiometricKeyManager())
    }
    
    
    func testSetupAndUnlockRoundTrip() async throws {
        let tempDir = makeTempDir()
        
        let appState = AppState(baseDir: tempDir, biometricManager: NoopBiometricKeyManager())
        let password = "CorrectHorseBatteryStaple"
        
        // Setup
        appState.setupVault(password: password)
        XCTAssertEqual(appState.mode, .unlocked)
        XCTAssertNotNil(appState.currentKey)
        XCTAssertTrue(FileManager.default.fileExists(atPath: appState.vaultURL.path))
        
        // Simulate relaunch with SAME baseDir
        let reloadState = AppState(baseDir: tempDir, biometricManager: NoopBiometricKeyManager())
        await reloadState.initialize()
        XCTAssertEqual(reloadState.mode, .locked)
        
        // Unlock
        reloadState.unlockWithPassword(password)
        XCTAssertEqual(reloadState.mode, .unlocked)
        XCTAssertNotNil(reloadState.journalStore)
    }
    
    func testChangePasswordKeepsEntries() async throws {
        let tempDir = makeTempDir()
        let appState = makeTempAppState(in: tempDir)
        let oldPassword = "old-password-123"
        let newPassword = "new-password-456"
        
        // Setup + add an entry
        appState.setupVault(password: oldPassword)
        guard let store = appState.journalStore else {
            XCTFail("No journalStore after setup")
            return
        }
        
        var entry = store.addEntry()
        entry.title = "My Entry"
        entry.body = "Some secret text"
        store.entries[0] = entry
        store.save()
        
        // Change password
        try appState.changePassword(currentPassword: oldPassword, newPassword: newPassword)
        
        // Simulate relaunch
        let relaunchState = makeTempAppState(in: tempDir)
        await relaunchState.initialize()
        XCTAssertEqual(relaunchState.mode, .locked)
        
        // Unlock with NEW password
        relaunchState.unlockWithPassword(newPassword)
        XCTAssertEqual(relaunchState.mode, .unlocked)
        XCTAssertEqual(relaunchState.journalStore?.entries.first?.title, "My Entry")
        XCTAssertEqual(relaunchState.journalStore?.entries.first?.body, "Some secret text")
    }
    
    func testForceResetMasterPasswordKeepsEntries() async throws {
        let tempDir = makeTempDir()
        let appState = makeTempAppState(in: tempDir)
        let originalPassword = "original-password"
        let newPassword = "reset-password"
        
        appState.setupVault(password: originalPassword)
        guard let store = appState.journalStore else {
            XCTFail("No journalStore after setup")
            return
        }
        
        var entry = store.addEntry()
        entry.title = "Entry Before Reset"
        entry.body = "Body before reset"
        store.entries[0] = entry
        store.save()
        
        // Force reset without checking old password
        try appState.forceSetNewMasterPassword(newPassword: newPassword)
        
        // Simulate relaunch
        let relaunchState = makeTempAppState(in: tempDir)
        await relaunchState.initialize()
        XCTAssertEqual(relaunchState.mode, .locked)
        
        // Old password should fail
        relaunchState.unlockWithPassword(originalPassword)
        XCTAssertEqual(relaunchState.mode, .locked, "Old password should not unlock after force reset")
        
        // Unlock with NEW password
        relaunchState.unlockWithPassword(newPassword)
        XCTAssertEqual(relaunchState.mode, .unlocked)
        XCTAssertEqual(relaunchState.journalStore?.entries.first?.title, "Entry Before Reset")
    }
    
//    func testIdleLockAfterTimeout() {
//        let tempDir = makeTempDir()
//        let appState = makeTempAppState(in: tempDir)
//
//        appState.mode = .unlocked
//        appState.vaultMeta = VaultMeta(
//            saltBase64: "dummy",
//            iterations: 100_000,
//            biometricsEnabled: false,
//            autoLockTimeoutSeconds: 1,
//            schemaVersion: 1
//        )
//
//        appState.lastActivity = Date(timeIntervalSinceNow: -5)
//        appState.checkIdleLock()
//
//        // Debug output to see what's going on
//        print("Mode after checkIdleLock:", appState.mode)
//
//        XCTAssertEqual(appState.mode, .locked)
//    }
//
//    func testIdleLockDisabledWhenTimeoutZero() {
//        let tempDir = makeTempDir()
//        let appState = makeTempAppState(in: tempDir)
//
//        appState.mode = .unlocked
//        appState.vaultMeta = VaultMeta(
//            saltBase64: "dummy",
//            iterations: 100_000,
//            biometricsEnabled: false,
//            autoLockTimeoutSeconds: 0, // disabled
//            schemaVersion: 1
//        )
//        appState.lastActivity = Date(timeIntervalSinceNow: -3600) // 1 hour ago
//
//        appState.checkIdleLock()
//
//        XCTAssertEqual(appState.mode, .unlocked, "Auto-lock should be disabled when timeout is 0")
//    }
}

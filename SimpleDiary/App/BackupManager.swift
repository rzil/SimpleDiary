import Foundation

/// Manages backup and restore of the app's vault data to and from iCloud Drive.
public struct BackupManager {
    private let appSupportBase: URL
    private let fileManager = FileManager.default
    
    /// Initializes the BackupManager with the base directory of the app's Application Support SimpleDiary folder.
    /// - Parameter appSupportBase: The URL pointing to the SimpleDiary directory in Application Support.
    public init(appSupportBase: URL) {
        self.appSupportBase = appSupportBase
    }
    
    /// Exports the current vault state to a specified destination directory by creating a timestamped backup folder and copying the index and vault files.
    ///
    /// - Parameters:
    ///   - destinationDirectory: The directory in which to create the backup folder.
    ///   - vaultID: The UUID of a specific vault to back up, or nil to back up all vaults.
    /// - Throws: An error if creating the backup folder or copying files fails.
    /// - Returns: The URL of the created backup folder.
    public func exportCurrentState(to destinationDirectory: URL, vaultID: UUID?) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let baseBackupFolderName = "Backup_\(timestamp)"
        
        var backupFolder = destinationDirectory.appendingPathComponent(baseBackupFolderName, isDirectory: true)
        var suffixIndex = 1
        while fileManager.fileExists(atPath: backupFolder.path) {
            backupFolder = destinationDirectory.appendingPathComponent("\(baseBackupFolderName)_\(suffixIndex)", isDirectory: true)
            suffixIndex += 1
        }
        
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true, attributes: nil)
        
        // Copy VaultsIndex.json
        let indexSource = appSupportBase.appendingPathComponent("VaultsIndex.json", isDirectory: false)
        let indexDest = backupFolder.appendingPathComponent("VaultsIndex.json", isDirectory: false)
        if fileManager.fileExists(atPath: indexSource.path) {
            try safeCopy(from: indexSource, to: indexDest, overwrite: false)
        }
        
        // Copy vault files
        let vaultsDir = appSupportBase.appendingPathComponent("Vaults", isDirectory: true)
        guard fileManager.fileExists(atPath: vaultsDir.path) else {
            // No vaults directory, so nothing more to copy
            return backupFolder
        }
        
        let vaultFiles: [URL]
        if let vaultID = vaultID {
            let specificVault = vaultsDir.appendingPathComponent("\(vaultID.uuidString).vault")
            if fileManager.fileExists(atPath: specificVault.path) {
                vaultFiles = [specificVault]
            } else {
                vaultFiles = []
            }
        } else {
            vaultFiles = try fileManager.contentsOfDirectory(at: vaultsDir, includingPropertiesForKeys: nil, options: [])
                .filter { $0.pathExtension == "vault" }
        }
        
        for vaultFile in vaultFiles {
            let destFile = backupFolder.appendingPathComponent(vaultFile.lastPathComponent)
            try safeCopy(from: vaultFile, to: destFile, overwrite: false)
        }
        
        return backupFolder
    }
    
    /// Returns the URL to the iCloud Drive backup directory under `Documents/SimpleDiaryBackups`, creating it if necessary.
    /// - Returns: The backup directory URL if iCloud is available, or nil otherwise.
    public func iCloudBackupDirectory() -> URL? {
        guard let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        let backupDir = ubiquityURL.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("SimpleDiaryBackups", isDirectory: true)
        if !fileManager.fileExists(atPath: backupDir.path) {
            do {
                try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return nil
            }
        }
        return backupDir
    }
    
    /// Exports the current vault state to iCloud Drive by creating a timestamped backup folder and copying the index and vault files.
    ///
    /// - Parameter vaultID: The UUID of a specific vault to back up, or nil to back up all vaults.
    /// - Throws: An error if the backup directory is unavailable or copying fails.
    /// - Returns: The URL of the created backup folder in iCloud Drive.
    public func exportCurrentStateToICloudDrive(vaultID: UUID?) throws -> URL {
        guard let backupDirectory = iCloudBackupDirectory() else {
            throw NSError(domain: "BackupError", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud backup directory is unavailable"])
        }
        return try exportCurrentState(to: backupDirectory, vaultID: vaultID)
    }
    
    /// Imports vault data from a given backup folder in iCloud Drive into the app's Application Support directory.
    ///
    /// - Parameters:
    ///   - backupFolder: The URL of the backup folder in iCloud Drive.
    ///   - replaceExisting: If true, existing files will be overwritten; if false, existing files will be preserved.
    /// - Throws: An error if the backup folder is invalid, unavailable, or copying fails.
    public func importFromBackup(at backupFolder: URL, replaceExisting: Bool) throws {
        let backupFolderStandardized = backupFolder.standardizedFileURL
        
        // Copy VaultsIndex.json if exists
        let indexFileBackup = backupFolderStandardized.appendingPathComponent("VaultsIndex.json", isDirectory: false)
        if fileManager.fileExists(atPath: indexFileBackup.path) {
            let indexFileDest = appSupportBase.appendingPathComponent("VaultsIndex.json", isDirectory: false)
            let data = try Data(contentsOf: indexFileBackup)
            try data.write(to: indexFileDest, options: .atomic)
        }
        
        // Ensure Vaults directory exists
        let vaultsDir = appSupportBase.appendingPathComponent("Vaults", isDirectory: true)
        if !fileManager.fileExists(atPath: vaultsDir.path) {
            try fileManager.createDirectory(at: vaultsDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Copy vault files
        let backupVaultFiles = try fileManager.contentsOfDirectory(at: backupFolderStandardized, includingPropertiesForKeys: nil, options: [])
            .filter { $0.pathExtension == "vault" }
        
        for backupVaultFile in backupVaultFiles {
            let destFile = vaultsDir.appendingPathComponent(backupVaultFile.lastPathComponent)
            if fileManager.fileExists(atPath: destFile.path) {
                if replaceExisting {
                    try safeCopy(from: backupVaultFile, to: destFile, overwrite: true)
                } else {
                    // Skip existing file
                    continue
                }
            } else {
                try safeCopy(from: backupVaultFile, to: destFile, overwrite: false)
            }
        }
    }
    
    /// Copies a file from a source URL to a destination URL safely, using atomic writes when overwriting or when the destination already exists.
    ///
    /// - Parameters:
    ///   - from: The source file URL.
    ///   - to: The destination file URL.
    ///   - overwrite: If true, will overwrite the destination file if it exists.
    /// - Throws: An error if the copy fails.
    private func safeCopy(from: URL, to: URL, overwrite: Bool) throws {
        if fileManager.fileExists(atPath: to.path) {
            if overwrite {
                let data = try Data(contentsOf: from)
                try data.write(to: to, options: .atomic)
            } else {
                // Destination exists and no overwrite allowed; throw error
                throw NSError(domain: "BackupError", code: 4, userInfo: [NSLocalizedDescriptionKey: "File already exists at destination: \(to.path)"])
            }
        } else {
            // Destination does not exist, try copyItem first
            do {
                try fileManager.copyItem(at: from, to: to)
            } catch {
                // fallback to atomic write
                let data = try Data(contentsOf: from)
                try data.write(to: to, options: .atomic)
            }
        }
    }
}


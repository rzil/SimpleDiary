import Foundation
import Combine
import CryptoKit
import SwiftUI

/// Stores encrypted journal entries on disk, using a provided symmetric key.
final class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = []
    
    private let key: SymmetricKey
    private let vaultURL: URL
    private var header: VaultHeader
    
    init(key: SymmetricKey, vaultURL: URL, header: VaultHeader) {
        self.key = key
        self.vaultURL = vaultURL
        self.header = header
    }
    
    /// Convenience init: given a key and vaultURL, read file, decrypt, and populate entries.
    convenience init(unlockingWith key: SymmetricKey, vaultURL: URL) throws {
        // Read header + ciphertext from the single vault file
        let (header, ciphertext) = try VaultFile.read(from: vaultURL)
        
        // Create base instance
        self.init(key: key, vaultURL: vaultURL, header: header)
        
        // Decrypt & decode entries
        let crypto = CryptoManager(key: key)
        let plaintext = try crypto.decrypt(ciphertext)
        let decoded = try JSONDecoder().decode([JournalEntry].self, from: plaintext)
        
        self.entries = decoded
    }
    
    // Save using header + key to same vault file
    func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            let crypto = CryptoManager(key: key)
            let ciphertext = try crypto.encrypt(data)
            try VaultFile.write(to: vaultURL, header: header, ciphertext: ciphertext)
        } catch {
            print("Failed to save journal:", error)
        }
    }

    func loadFromVaultFile() throws {
        let (header, ciphertext) = try VaultFile.read(from: vaultURL)
        self.header = header

        let crypto = CryptoManager(key: key)
        let plaintext = try crypto.decrypt(ciphertext)
        let decoded = try JSONDecoder().decode([JournalEntry].self, from: plaintext)
        self.entries = decoded
    }

    func addEntry() -> JournalEntry {
        let entry = JournalEntry(
            id: UUID(),
            date: Date(),
            title: "",
            body: ""
        )
        entries.insert(entry, at: 0)
        save()
        return entry
    }
    
    func deleteEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }
    
    @discardableResult
    func duplicateEntry(withID id: JournalEntry.ID) -> JournalEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let original = entries[index]
        // Construct a new entry instead of mutating `id` (which is likely a `let`)
        let newTitle: String = {
            if original.title.isEmpty { return original.title }
            return "\(original.title) (Copy)"
        }()
        let copy = JournalEntry(
            id: UUID(),
            date: Date(),
            title: newTitle,
            body: original.body
        )
        // Insert right after the original's current position
        let insertIndex = index + 1
        if insertIndex <= entries.count {
            entries.insert(copy, at: insertIndex)
        } else {
            entries.append(copy)
        }
        save()
        return copy
    }
}

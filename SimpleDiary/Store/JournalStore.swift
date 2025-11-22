
import Foundation
import Combine
import CryptoKit

/// Stores encrypted journal entries on disk, using a provided symmetric key.
final class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = []

    private let crypto: CryptoManager
    private let fileURL: URL

    init(key: SymmetricKey, baseDir: URL) throws {
        self.crypto = CryptoManager(key: key)
        self.fileURL = baseDir.appendingPathComponent("entries.bin")
        try load()
    }

    func load() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }

        let encryptedData = try Data(contentsOf: fileURL)
        let decrypted = try crypto.decrypt(encryptedData)
        entries = try JSONDecoder().decode([JournalEntry].self, from: decrypted)
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            let encrypted = try crypto.encrypt(data)
            try encrypted.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save journal:", error)
        }
    }

    @discardableResult
    func addEntry() -> JournalEntry {
        let entry = JournalEntry()
        entries.insert(entry, at: 0)
        save()
        return entry
    }

    func updateEntry(_ entry: JournalEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
            save()
        }
    }
}

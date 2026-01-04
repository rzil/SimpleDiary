import Testing
import Foundation
@testable import SimpleDiary

@Suite("Vault file read/write")
struct VaultFileRoundTripTests {
    @Test("Write then read returns identical header and ciphertext")
    func roundTrip() throws {
        // Prepare header and random ciphertext
        let header = VaultHeader(schemaVersion: 1, saltBase64: Data([1,2,3,4]).base64EncodedString(), iterations: 42)
        var bigCipher = Data(count: 1024)
        _ = bigCipher.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, ptr.count, ptr.baseAddress!)
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }

        try VaultFile.write(to: url, header: header, ciphertext: bigCipher)
        let (readHeader, readCipher) = try VaultFile.read(from: url)

        #expect(readHeader.schemaVersion == header.schemaVersion)
        #expect(readHeader.saltBase64 == header.saltBase64)
        #expect(readHeader.iterations == header.iterations)
        #expect(readCipher == bigCipher)
    }

    @Test("Unsupported schema version throws .unsupportedSchemaVersion")
    @MainActor func unsupportedSchema() throws {
        // Build a manual file with schemaVersion 999
        let badHeader = VaultHeader(schemaVersion: 999, saltBase64: Data([9,9,9]).base64EncodedString(), iterations: 100)
        let headerData = try JSONEncoder().encode(badHeader)
        var fileData = Data()
        // magic
        fileData.append(VaultFile.magic)
        // header length (big-endian UInt32)
        let length = UInt32(headerData.count)
        fileData.append(UInt8((length >> 24) & 0xFF))
        fileData.append(UInt8((length >> 16) & 0xFF))
        fileData.append(UInt8((length >> 8) & 0xFF))
        fileData.append(UInt8(length & 0xFF))
        // header JSON
        fileData.append(headerData)
        // ciphertext (empty OK)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try fileData.write(to: url)

        do {
            _ = try VaultFile.read(from: url)
            #expect(Bool(false), "Expected read to throw")
        } catch VaultFileError.unsupportedSchemaVersion(let v) {
            #expect(v == 999)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}


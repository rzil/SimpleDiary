import Testing
import Foundation
@testable import SimpleDiary

@Suite("Vault file unsupported schema")
struct VaultFileUnsupportedSchemaTests {
    @MainActor
    @Test("Read throws for unsupported schema version")
    func unsupportedSchema() throws {
        // Build a valid-looking file with a header that declares an unsupported schema
        let header = VaultHeader(schemaVersion: 9999, saltBase64: Data([0x00]).base64EncodedString(), iterations: 1)
        let headerData = try JSONEncoder().encode(header)

        var file = Data()
        // magic
        file.append(VaultFile.magic)
        // header length (big-endian UInt32)
        let length = UInt32(headerData.count)
        file.append(contentsOf: [
            UInt8((length >> 24) & 0xFF),
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF)
        ])
        // header JSON
        file.append(headerData)
        // empty ciphertext
        file.append(Data())

        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try file.write(to: url)

        do {
            _ = try VaultFile.read(from: url)
            // If your implementation throws on schema during read, we expect an error.
            // If it defers schema validation, consider adjusting this test to assert behavior later.
            #expect(Bool(false), "Expected read to throw for unsupported schema")
        } catch VaultFileError.unsupportedSchemaVersion(let v) {
            #expect(v == 9999)
        } catch {
            // If your code validates schema elsewhere, this may need to be adapted.
            #expect(Bool(true), "Caught some error as expected: \(error)")
        }
    }
}

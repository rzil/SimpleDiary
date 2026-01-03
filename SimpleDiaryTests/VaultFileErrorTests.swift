import Testing
import Foundation
@testable import SimpleDiary

@Suite("Vault file errors")
struct VaultFileErrorTests {
    @Test("Invalid magic throws .invalidMagic")
    func invalidMagic() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try Data([0x00, 0x01, 0x02]).write(to: url)
        do {
            _ = try VaultFile.read(from: url)
            #expect(Bool(false), "Expected read to throw")
        } catch VaultFileError.invalidMagic {
            // success
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Truncated header throws .truncatedHeader")
    func truncatedHeader() throws {
        // Build a file with correct magic but incomplete header length
        var data = Data()
        data.append(VaultFile.magic)
        // Write a header length of 100 bytes but provide fewer bytes
        data.append(contentsOf: [0,0,0,100])
        data.append(Data([0x7B, 0x7D])) // '{}'
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        do {
            _ = try VaultFile.read(from: url)
            #expect(Bool(false), "Expected read to throw")
        } catch VaultFileError.truncatedHeader {
            // success
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}

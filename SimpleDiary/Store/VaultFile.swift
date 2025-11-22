//
//  VaultFile.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 23/11/2025.
//

import Foundation
import CryptoKit

struct VaultHeader: Codable {
    var schemaVersion: Int
    var saltBase64: String
    var iterations: Int
}

enum VaultFileError: Error {
    case invalidMagic
    case truncatedHeader
    case unsupportedSchemaVersion(Int)
}

struct VaultFile {
    static let magic = "DVAULT1".data(using: .utf8)!  // 7 bytes
    
    /// Write header + ciphertext to a single vault file atomically.
    static func write(
        to url: URL,
        header: VaultHeader,
        ciphertext: Data
    ) throws {
        let headerData = try JSONEncoder().encode(header)
        var fileData = Data()
        
        // magic
        fileData.append(magic)
        
        // header length as big-endian UInt32
        var headerLength = UInt32(headerData.count).bigEndian
        withUnsafeBytes(of: &headerLength) { fileData.append(contentsOf: $0) }
        
        // header JSON
        fileData.append(headerData)
        
        // ciphertext
        fileData.append(ciphertext)
        
        try fileData.write(to: url, options: [.atomic])
    }
    
    /// Read header + ciphertext from vault file.
    static func read(from url: URL) throws -> (header: VaultHeader, ciphertext: Data) {
        let data = try Data(contentsOf: url)
        var offset = 0
        
        // magic
        guard data.count >= magic.count else { throw VaultFileError.invalidMagic }
        let magicData = data.subdata(in: offset ..< offset+magic.count)
        guard magicData == magic else { throw VaultFileError.invalidMagic }
        offset += magic.count
        
        // header length
        let lengthSize = MemoryLayout<UInt32>.size
        guard data.count >= offset + lengthSize else {
            throw VaultFileError.truncatedHeader
        }
        let lengthData = data.subdata(in: offset ..< offset + lengthSize)
        let headerLength = lengthData.withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }
        offset += lengthSize
        
        // header JSON
        guard data.count >= offset + Int(headerLength) else {
            throw VaultFileError.truncatedHeader
        }
        let headerData = data.subdata(in: offset ..< offset + Int(headerLength))
        offset += Int(headerLength)
        
        let header = try JSONDecoder().decode(VaultHeader.self, from: headerData)
        
        // ciphertext is "the rest"
        let ciphertext = data.suffix(from: offset)
        
        return (header, ciphertext)
    }
}

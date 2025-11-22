
import Foundation

import Foundation

struct VaultMeta: Codable {
    var saltBase64: String
    var iterations: Int
    var biometricsEnabled: Bool
    var autoLockTimeoutSeconds: Int?
    
    /// Version of the vault format / crypto scheme.
    /// Start at 1; default to 1 if missing (older vaults).
    var schemaVersion: Int
    
    enum CodingKeys: String, CodingKey {
        case saltBase64
        case iterations
        case biometricsEnabled
        case autoLockTimeoutSeconds
        case schemaVersion
    }
    
    init(
        saltBase64: String,
        iterations: Int,
        biometricsEnabled: Bool,
        autoLockTimeoutSeconds: Int?,
        schemaVersion: Int = 1
    ) {
        self.saltBase64 = saltBase64
        self.iterations = iterations
        self.biometricsEnabled = biometricsEnabled
        self.autoLockTimeoutSeconds = autoLockTimeoutSeconds
        self.schemaVersion = schemaVersion
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        saltBase64 = try container.decode(String.self, forKey: .saltBase64)
        iterations = try container.decode(Int.self, forKey: .iterations)
        biometricsEnabled = try container.decode(Bool.self, forKey: .biometricsEnabled)
        autoLockTimeoutSeconds = try container.decodeIfPresent(Int.self, forKey: .autoLockTimeoutSeconds)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}

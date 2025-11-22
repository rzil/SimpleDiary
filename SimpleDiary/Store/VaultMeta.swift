
import Foundation

struct VaultMeta: Codable {
    var saltBase64: String
    var iterations: Int
    var biometricsEnabled: Bool
    var autoLockTimeoutSeconds: Int?

    /// Version of the vault format / crypto scheme.
    /// Start at 1; bump when you change how the vault is encrypted or encoded.
    var schemaVersion: Int
}

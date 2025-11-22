
import Foundation

struct VaultMeta: Codable {
    var saltBase64: String
    var iterations: Int
    var biometricsEnabled: Bool
    
    /// Idle auto-lock timeout in seconds. 0 or negative = disabled.
    var autoLockTimeoutSeconds: Int?
}

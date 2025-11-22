
import Foundation

struct VaultMeta: Codable {
    var saltBase64: String
    var iterations: Int
    var biometricsEnabled: Bool
}

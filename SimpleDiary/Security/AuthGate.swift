import Combine
import Foundation
import LocalAuthentication

final class AuthGate: ObservableObject {
    @Published var isUnlocked = false
    @Published var lastError: Error?

    private var isAuthenticating = false

    func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true

        let context = LAContext()
        let policy: LAPolicy = .deviceOwnerAuthentication

        var authError: NSError?
        guard context.canEvaluatePolicy(policy, error: &authError) else {
            DispatchQueue.main.async {
                self.lastError = authError
                self.isUnlocked = false
                self.isAuthenticating = false
            }
            return
        }

        context.evaluatePolicy(policy, localizedReason: "Unlock your journal") { success, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                if success {
                    self.isUnlocked = true
                    self.lastError = nil
                } else {
                    self.isUnlocked = false
                    self.lastError = error
                }
            }
        }
    }

    func lock() {
        isUnlocked = false
    }
}

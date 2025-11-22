
import SwiftUI

struct SetupPasswordView: View {
    @EnvironmentObject var appState: AppState
    @State private var password: String = ""
    @State private var confirm: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Set Master Password")
                .font(.title)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)

            SecureField("Confirm Password", text: $confirm)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button("Create Vault") {
                createVault()
            }
            .disabled(password.isEmpty || confirm.isEmpty)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createVault() {
        guard password == confirm else {
            errorMessage = "Passwords do not match."
            return
        }
        errorMessage = nil
        appState.setupVault(password: password)
        password = ""
        confirm = ""
    }
}

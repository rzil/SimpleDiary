
import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var appState: AppState
    @State private var password: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Unlock Journal")
                .font(.title)

            SecureField("Master Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                Button("Unlock") {
                    unlock()
                }
                .disabled(password.isEmpty)

                if appState.vaultMeta?.biometricsEnabled == true {
                    Button {
                        appState.unlockWithBiometrics()
                    } label: {
                        Label("Touch ID", systemImage: "touchid")
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unlock() {
        let pw = password
        password = ""
        errorMessage = nil
        appState.unlockWithPassword(pw)
        // In a real app you'd observe an error state from AppState and set errorMessage
    }
}

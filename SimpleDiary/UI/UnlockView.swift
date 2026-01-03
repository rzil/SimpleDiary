import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var appState: DiaryAppState
    @State private var password: String = ""
    @State private var errorMessage: String?
    
    // Compute the selected vault's display name from the index
    private var selectedVaultName: String? {
        guard let id = appState.selectedVaultID else { return nil }
        return appState.vaults.first(where: { $0.id == id })?.name
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Unlock Journal")
            
            if let name = selectedVaultName, !name.isEmpty {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

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
        // In a real app you'd observe an error state from DiaryAppState and set errorMessage
    }
}


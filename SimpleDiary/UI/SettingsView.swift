import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.title2)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            Toggle(
                "Enable Touch ID / biometrics unlock",
                isOn: Binding(
                    get: { appState.vaultMeta?.biometricsEnabled ?? false },
                    set: { newValue in
                        appState.setBiometricsEnabled(newValue)
                    }
                )
            )
            
            Text("Biometrics are optional convenience. Your master password remains the ultimate key to decrypt the journal.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(width: 380, height: 200)
    }
}

import SwiftUI
import AppKit

enum AutoLockOption: Int, CaseIterable, Identifiable {
    case off = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .off: return "Never"
        case .oneMinute: return "After 1 minute"
        case .fiveMinutes: return "After 5 minutes"
        case .fifteenMinutes: return "After 15 minutes"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingChangePassword = false
    @State private var showingForceReset = false
    
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
            
            // Biometrics toggle
            Toggle(
                "Enable Touch ID / biometrics unlock",
                isOn: Binding(
                    get: { appState.vaultMeta?.biometricsEnabled ?? false },
                    set: { newValue in
                        appState.setBiometricsEnabled(newValue)
                    }
                )
            )
            
            // Auto-lock picker
            Picker(
                "Auto-lock when idle",
                selection: Binding<AutoLockOption>(
                    get: {
                        let seconds = appState.vaultMeta?.autoLockTimeoutSeconds ?? (5 * 60)
                        return AutoLockOption(rawValue: seconds) ?? .fiveMinutes
                    },
                    set: { newValue in
                        appState.updateAutoLockTimeout(seconds: newValue.rawValue)
                    }
                )
            ) {
                ForEach(AutoLockOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            
            Button("Show vault file in Finder…") {
                revealVaultInFinder()
            }
            .disabled({
                guard let url = appState.selectedVaultURL else { return true }
                return !FileManager.default.fileExists(atPath: url.path)
            }())
            .help("Reveals the encrypted vault file in Finder. Don’t delete it unless you have a backup.")
            
            Button("Change master password…") {
                showingChangePassword = true
            }
            .padding(.top, 4)
            
#if DEBUG
            Button("Force reset master password…") {
                showingForceReset = true
            }
            .font(.caption)
            .foregroundColor(.red)
            .help("Use only if you are already unlocked (e.g. via Touch ID) and the old password is not recognised.")
#endif
            
            Text("Biometrics are optional convenience. Your master password remains the ultimate key to decrypt the journal.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(width: 380, height: 320)
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingForceReset) {
            ForceResetPasswordView()
                .environmentObject(appState)
        }
    }
    
    private func revealVaultInFinder() {
        guard let url = appState.selectedVaultURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

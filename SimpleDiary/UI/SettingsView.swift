import SwiftUI

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
            
            Toggle(
                "Enable Touch ID / biometrics unlock",
                isOn: Binding(
                    get: { appState.vaultMeta?.biometricsEnabled ?? false },
                    set: { newValue in
                        appState.setBiometricsEnabled(newValue)
                    }
                )
            )
            
            Picker("Auto-lock when idle", selection: Binding<AutoLockOption>(
                get: {
                    let seconds = appState.vaultMeta?.autoLockTimeoutSeconds ?? (5 * 60)
                    // Map seconds to nearest option
                    return AutoLockOption(rawValue: seconds) ?? .fiveMinutes
                },
                set: { newValue in
                    guard var meta = appState.vaultMeta else { return }
                    meta.autoLockTimeoutSeconds = newValue.rawValue
                    do {
                        try appState.setVaultMeta(meta)
                    } catch {
                        print("Failed to update auto-lock setting:", error)
                    }
                }
            )) {
                ForEach(AutoLockOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            
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
        .frame(width: 380, height: 260)
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingForceReset) {
            ForceResetPasswordView()
                .environmentObject(appState)
        }
    }
}

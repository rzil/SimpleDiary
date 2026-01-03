import SwiftUI
import Foundation

struct VaultsManagerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateSheet = false
    @State private var newVaultName = ""
    @State private var newVaultPassword = ""

    @State private var showingRenameSheet = false
    @State private var renameVault: VaultInfo?
    @State private var renameVaultName = ""

    @State private var showingDeleteAlert = false
    @State private var deleteVault: VaultInfo?

    var body: some View {
        NavigationView {
            List {
                ForEach(appState.vaults) { vault in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(vault.name)
                                .font(.headline)
                            Text("Last opened: \(formattedLastOpened(for: vault))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if appState.selectedVaultID == vault.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contextMenu {
                        Button("Select") {
                            appState.selectVault(vault.id)
                        }
                        Button("Rename") {
                            renameVault = vault
                            renameVaultName = vault.name
                            showingRenameSheet = true
                        }
                        Button(role: .destructive) {
                            deleteVault = vault
                            showingDeleteAlert = true
                        } label: {
                            Text("Delete")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectVault(vault.id)
                    }
                }
            }
            .navigationTitle("Manage Vaults")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newVaultName = ""
                        newVaultPassword = ""
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create new vault")
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Vault Info")) {
                            TextField("Name", text: $newVaultName)
                            SecureField("Password", text: $newVaultPassword)
                        }
                    }
                    .navigationTitle("Create Vault")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                appState.createVault(named: newVaultName, password: newVaultPassword)
                                showingCreateSheet = false
                            }
                            .disabled(newVaultName.trimmingCharacters(in: .whitespaces).isEmpty || newVaultPassword.isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingCreateSheet = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRenameSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Rename Vault")) {
                            TextField("New Name", text: $renameVaultName)
                        }
                    }
                    .navigationTitle("Rename Vault")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Rename") {
                                if let vault = renameVault,
                                   !renameVaultName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    appState.renameVault(vault.id, to: renameVaultName)
                                }
                                showingRenameSheet = false
                            }
                            .disabled(renameVaultName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingRenameSheet = false
                            }
                        }
                    }
                }
            }
            .alert("Delete Vault", isPresented: $showingDeleteAlert, presenting: deleteVault) { vault in
                Button("Delete", role: .destructive) {
                    appState.deleteVault(vault.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: { vault in
                Text("Are you sure you want to delete the vault \"\(vault.name)\"? This action cannot be undone.")
            }
        }
    }
}

private func formattedLastOpened(for vault: VaultInfo) -> String {
    if let date = vault.lastOpened {
        return dateFormatter.string(from: date)
    } else {
        return "Never"
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - Preview

#if DEBUG
struct VaultsManagerView_Previews: PreviewProvider {
    static var previews: some View {
        VaultsManagerView()
            .environmentObject(AppState())
    }
}
#endif

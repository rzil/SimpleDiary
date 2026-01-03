import SwiftUI
import AppKit

struct VaultsMenuCommands: Commands {
    @ObservedObject var appState: DiaryAppState

    var body: some Commands {
        CommandMenu("Vaults") {
            ForEach(appState.vaults) { vault in
                Button(action: {
                    appState.selectVault(vault.id)
                }) {
                    Text(vault.id == appState.selectedVaultID ? "✓ \(vault.name)" : vault.name)
                }
            }
            Divider()
            Button("Manage Vaults…") {
                openVaultsManagerWindow()
            }
            Divider()
            Button("Create New Vault…") {
                showCreateNewVaultAlert()
            }
            Button("Rename Selected Vault…") {
                guard let selectedID = appState.selectedVaultID else { return }
                showRenameVaultAlert(for: selectedID)
            }
            .disabled(appState.selectedVaultID == nil)
            Button("Delete Selected Vault…") {
                guard let selectedID = appState.selectedVaultID else { return }
                showDeleteVaultAlert(for: selectedID)
            }
            .disabled(appState.selectedVaultID == nil)
        }
    }

    private func openVaultsManagerWindow() {
        let vc = NSHostingController(rootView: VaultsManagerView().environmentObject(appState))
        let window = NSWindow(contentViewController: vc)
        window.title = "Manage Vaults"
        window.setContentSize(NSSize(width: 480, height: 420))
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showCreateNewVaultAlert() {
        let alert = NSAlert()
        alert.messageText = "Create New Vault"
        alert.informativeText = "Enter a name and password for the new vault."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let nameField = NSTextField(frame: NSRect(x: 0, y: 54, width: 200, height: 24))
        nameField.placeholderString = "Name"
        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 18, width: 200, height: 24))
        passwordField.placeholderString = "Password"

        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 78))
        accessoryView.addSubview(nameField)
        accessoryView.addSubview(passwordField)
        alert.accessoryView = accessoryView

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let password = passwordField.stringValue
            if !name.isEmpty {
                appState.createVault(named: name, password: password)
            }
        }
    }

    private func showRenameVaultAlert(for vaultID: UUID) {
        let alert = NSAlert()
        alert.messageText = "Rename Vault"
        alert.informativeText = "Enter a new name for the selected vault."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        if let vault = appState.vaults.first(where: { $0.id == vaultID }) {
            nameField.stringValue = vault.name
        }
        alert.accessoryView = nameField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                appState.renameVault(vaultID, to: newName)
            }
        }
    }

    private func showDeleteVaultAlert(for vaultID: UUID) {
        guard let vault = appState.vaults.first(where: { $0.id == vaultID }) else { return }
        let alert = NSAlert()
        alert.messageText = "Delete Vault"
        alert.informativeText = "Are you sure you want to delete the vault \"\(vault.name)\"? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            appState.deleteVault(vaultID)
        }
    }
}

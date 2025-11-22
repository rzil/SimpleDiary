//
//  AppMenuCommands.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 22/11/2025.
//

import SwiftUI

struct AppMenuCommands: Commands {
    @ObservedObject var appState: AppState
    
    var body: some Commands {
        CommandMenu("Journal") {
            Button("Lock") {
                appState.lock()
            }
            .keyboardShortcut("L", modifiers: .command)
            .disabled(appState.mode != .unlocked)

            Button("Show Vault in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([appState.vaultURL])
            }
            .disabled(!FileManager.default.fileExists(atPath: appState.vaultURL.path))
        }
    }
}

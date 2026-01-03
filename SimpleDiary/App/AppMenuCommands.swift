//
//  AppMenuCommands.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 22/11/2025.
//

import SwiftUI
import AppKit

struct AppMenuCommands: Commands {
    @ObservedObject var appState: DiaryAppState
    
    var body: some Commands {
        CommandMenu("Journal") {
            Button("Lock") {
                appState.lock()
            }
            .keyboardShortcut("L", modifiers: .command)
            .disabled(appState.mode != .unlocked)

            Button("Show Vault in Finder") {
                if let url = appState.selectedVaultURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            .disabled({
                guard let url = appState.selectedVaultURL else { return true }
                return !FileManager.default.fileExists(atPath: url.path)
            }())
        }
    }
}

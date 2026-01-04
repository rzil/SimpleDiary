//
//  SimpleDiaryApp.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 22/11/2025.
//

import Combine
import SwiftUI

final class AppNotifier: ObservableObject {
    struct AlertContent: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    @Published var alert: AlertContent?
}

@main
struct SimpleDiaryApp: App {
    @StateObject private var appState = DiaryAppState()
    @StateObject private var notifier = AppNotifier()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(notifier)
                .alert(item: $notifier.alert) { content in
                    Alert(
                        title: Text(content.title),
                        message: Text(content.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }
        .windowStyle(.titleBar)
        .commands {
            AppMenuCommands(appState: appState)
            VaultsMenuCommands(appState: appState)
            CommandMenu("Backups") {
                Button("Export Backup to iCloud Drive") {
                    Task {
                        do {
                            let folderURL = try appState.exportBackupToICloud()
                            notifier.alert = .init(title: "Backup Exported", message: "Exported to: \(folderURL.lastPathComponent)")
                        } catch {
                            notifier.alert = .init(title: "Backup Export Failed", message: error.localizedDescription)
                        }
                    }
                }
                Button("Restore from Backup…") {
                    #if os(macOS)
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.prompt = "Choose Backup Folder"
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            Task {
                                do {
                                    try appState.importBackupFromICloud(backupFolder: url, replaceExisting: true)
                                    notifier.alert = .init(title: "Restore Complete", message: "Restored from: \(url.lastPathComponent)")
                                } catch {
                                    notifier.alert = .init(title: "Restore Failed", message: error.localizedDescription)
                                }
                            }
                        }
                    }
                    #endif
                }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: DiaryAppState
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            switch appState.mode {
            case .initializing:
                ProgressView("Loading…")
                    .task {
                        await appState.initialize()
                    }
            case .needsSetup:
                SetupPasswordView()
            case .locked:
                UnlockView()
            case .unlocked:
                if let store = appState.journalStore {
                    JournalRootView()
                        .environmentObject(store)
                } else {
                    Text("Error: No store")
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                appState.lock()
            }
        }
        .onReceive(
            Timer.publish(every: 30, on: .main, in: .common).autoconnect()
        ) { _ in
            appState.checkIdleLock()
        }
    }
}


import SwiftUI
import UniformTypeIdentifiers
import Combine

struct BackupsMenuCommands: Commands {
    let appState: DiaryAppState
    let notifier: AppNotifier

    var body: some Commands {
        CommandMenu("Backups") {
            Button("Export Backup to Folder…") {
                #if os(macOS)
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.prompt = "Choose Destination Folder"
                panel.begin { response in
                    if response == .OK, let dest = panel.url {
                        Task {
                            do {
                                let folderURL = try appState.exportBackup(to: dest)
                                notifier.alert = .init(title: "Backup Exported", message: "Exported to: \(folderURL.lastPathComponent)")
                            } catch {
                                notifier.alert = .init(title: "Backup Export Failed", message: error.localizedDescription)
                            }
                        }
                    }
                }
                #endif
            }
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

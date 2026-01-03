import SwiftUI

struct JournalRootView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var appState: DiaryAppState
    
    @State private var selectedID: JournalEntry.ID?
    @State private var showingSettings = false
    @State private var sortNewestFirst = true   // NEW

    var body: some View {
        NavigationSplitView {
            let entries = store.entries.sorted {
                sortNewestFirst
                    ? $0.date > $1.date
                    : $0.date < $1.date
            }
            
            List(selection: $selectedID) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                            .font(.headline)
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let tag = entry.tag {
                            Text(tag)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(entry.id)
                }
                .onDelete { indexSet in
                    // Must map visible indexSet back to original store.entries indexes
                    let sortedIndices = indexSet.map { sortedIndex in
                        store.entries.firstIndex(where: { $0.id == entries[sortedIndex].id })!
                    }

                    let indexSetReal = IndexSet(sortedIndices)
                    
                    if let selectedID = selectedID {
                        let idsBeingDeleted = indexSetReal.map { store.entries[$0].id }
                        if idsBeingDeleted.contains(selectedID) {
                            self.selectedID = nil
                        }
                    }
                    
                    store.deleteEntries(at: indexSetReal)
                    appState.noteActivity()
                }
            }
            .navigationTitle(appState.vaults.first(where: { $0.id == appState.selectedVaultID })?.name ?? "Journal")
            .onChange(of: selectedID) {
                appState.noteActivity()
            }
            .toolbar {
                // New Entry
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let new = store.addEntry()
                        selectedID = new.id
                        appState.noteActivity()
                    } label: {
                        Label("New Entry", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("N", modifiers: .command)
                }
                
                // Delete
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let id = selectedID,
                           let idx = store.entries.firstIndex(where: { $0.id == id }) {
                            store.deleteEntries(at: IndexSet(integer: idx))
                            selectedID = nil
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedID == nil)
                }

                // 🔽 Sort toggle
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sortNewestFirst.toggle()
                    } label: {
                        Image(systemName: sortNewestFirst ? "arrow.down" : "arrow.up")
                    }
                    .help(sortNewestFirst ? "Sort Oldest → Newest" : "Sort Newest → Oldest")
                }

                // Settings
                ToolbarItem(placement: .navigation) {
                    Button {
                        showingSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Text(appState.vaults.first(where: { $0.id == appState.selectedVaultID })?.name ?? "—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .help("Current vault")
                }

                ToolbarItem(placement: .navigation) {
                    Picker("Vault", selection: Binding(
                        get: { appState.selectedVaultID ?? UUID() },
                        set: { newID in appState.selectVault(newID) }
                    )) {
                        ForEach(appState.vaults) { v in
                            Text(v.name).tag(v.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 160)
                    .help("Switch vault")
                }

                // Lock
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        appState.lock()
                    } label: {
                        Label("Lock", systemImage: "lock.fill")
                    }
                    .keyboardShortcut("L", modifiers: .command)
                }
            }
        } detail: {
            if let id = selectedID,
               let index = store.entries.firstIndex(where: { $0.id == id }) {
                JournalEditorView(entry: $store.entries[index])
            } else {
                ContentUnavailableView("Select or create an entry", systemImage: "book")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(appState)
        }
    }
}


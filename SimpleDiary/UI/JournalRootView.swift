
import SwiftUI

struct JournalRootView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var appState: AppState
    @State private var selectedID: JournalEntry.ID?
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(store.entries) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                            .font(.headline)
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(entry.id)
                }
                .onDelete { indexSet in
                    // Clear selection if we delete the selected entry
                    if let selectedID = selectedID {
                        let idsBeingDeleted = indexSet.map { store.entries[$0].id }
                        if idsBeingDeleted.contains(selectedID) {
                            self.selectedID = nil
                        }
                    }
                    
                    store.deleteEntries(at: indexSet)
                    appState.noteActivity()
                }
            }
            .onChange(of: selectedID) {
                appState.noteActivity()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let new = store.addEntry()
                        selectedID = new.id
                        appState.noteActivity()
                    } label: {
                        Label("New Entry", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("N", modifiers: .command)
                    .help("New Entry (⌘N)")
                }
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
                ToolbarItem(placement: .navigation) {
                    Button {
                        showingSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        appState.lock()
                    } label: {
                        Label("Lock", systemImage: "lock.fill")
                    }
                    .keyboardShortcut("L", modifiers: .command)
                    .help("Lock (⌘L)")
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
            SettingsView()
                .environmentObject(appState)
        }
    }
}


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
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let new = store.addEntry()
                        selectedID = new.id
                    } label: {
                        Label("New Entry", systemImage: "square.and.pencil")
                    }
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
                        Image(systemName: "lock.fill")
                    }
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

import SwiftUI

struct JournalRootView: View {
    @EnvironmentObject var store: JournalStore
    @State private var selectedID: JournalEntry.ID?
    
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
                    // This connects the row to the List's selection binding
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
            }
        } detail: {
            if let id = selectedID,
               let index = store.entries.firstIndex(where: { $0.id == id }) {
                // Pass a *binding* into the array, not a copy
                JournalEditorView(entry: $store.entries[index])
            } else {
                ContentUnavailableView("Select or create an entry", systemImage: "book")
            }
        }
    }
}

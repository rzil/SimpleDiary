import SwiftUI

struct JournalEditorView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var appState: AppState
    @Binding var entry: JournalEntry
    
    @State private var saveWorkItem: DispatchWorkItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $entry.title)
                .font(.title)
            
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
            
            TextEditor(text: $entry.body)
                .font(.body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onChange(of: entry) { _ in
            scheduleSave()
        }
    }
    
    private func scheduleSave() {
        // Any edit counts as activity
        appState.noteActivity()
        
        // Cancel previous pending save
        saveWorkItem?.cancel()
        
        let work = DispatchWorkItem { [store] in
            store.save()
        }
        saveWorkItem = work
        
        // Save after 0.7 seconds of no further edits
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }
}

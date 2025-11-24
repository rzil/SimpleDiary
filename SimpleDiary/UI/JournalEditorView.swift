import SwiftUI

struct JournalEditorView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var appState: AppState
    @Binding var entry: JournalEntry
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $entry.title)
                .font(.title)
                .focused($isTitleFocused)
            
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
            
            TextEditor(text: $entry.body)
                .font(.body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onChange(of: entry) {
            appState.scheduleSave()
        }
        .onAppear { isTitleFocused = true }
    }
}

import SwiftUI

struct JournalEditorView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var appState: AppState
    @Binding var entry: JournalEntry
    @FocusState private var isTitleFocused: Bool
    
    // Persist the editor font size across launches
    @AppStorage("editorBodyPointSize") private var bodyPointSize: Double = 17
    
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
                .font(.system(size: CGFloat(bodyPointSize)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onChange(of: entry) {
            appState.scheduleSave()
        }
        .onAppear { isTitleFocused = true }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    bodyPointSize = max(bodyPointSize - 1, 10)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Decrease Text Size (Cmd -)")
                .keyboardShortcut("-", modifiers: [.command])

                Button {
                    bodyPointSize = 17
                } label: {
                    Image(systemName: "textformat.size")
                }
                .help("Actual Size (Cmd 0)")
                .keyboardShortcut("0", modifiers: [.command])

                Button {
                    bodyPointSize = min(bodyPointSize + 1, 36)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Increase Text Size (Cmd +)")
                .keyboardShortcut("=", modifiers: [.command])
            }
        }
    }
}

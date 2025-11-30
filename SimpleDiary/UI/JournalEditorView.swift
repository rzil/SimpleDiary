import SwiftUI

struct JournalEditorView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var appState: AppState
    @Binding var entry: JournalEntry
    @FocusState private var isTitleFocused: Bool
    
    // Persist the editor font size across launches
    @AppStorage("editorBodyPointSize") private var bodyPointSize: Double = 17

    // Find bar state
    @State private var isFindBarVisible: Bool = false
    @State private var findQuery: String = ""
    @FocusState private var isFindFocused: Bool
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    private func updateMatches() {
        let text = entry.body
        let query = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            totalMatches = 0
            currentMatchIndex = 0
            return
        }
        // Simple case-insensitive count of occurrences
        totalMatches = text.lowercased().components(separatedBy: query.lowercased()).count - 1
        currentMatchIndex = min(max(currentMatchIndex, 0), max(totalMatches - 1, 0))
    }

    private func goToNextMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
        // TODO: Scroll to the selected match if needed (bridge to NSTextView/UITextView)
    }

    private func goToPreviousMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
        // TODO: Scroll to the selected match if needed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $entry.title)
                .font(.title)
                .focused($isTitleFocused)
            
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
            
            if isFindBarVisible {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Find", text: $findQuery)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 200)
                        .focused($isFindFocused)
                        .onSubmit { goToNextMatch() }
                        .onChange(of: findQuery) { updateMatches() }
                        .onAppear { updateMatches() }

                    if totalMatches > 0 {
                        Text("\(currentMatchIndex + 1) of \(totalMatches)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: goToPreviousMatch) {
                        Image(systemName: "chevron.up")
                    }
                    .help("Previous Match")
                    .disabled(totalMatches == 0)

                    Button(action: goToNextMatch) {
                        Image(systemName: "chevron.down")
                    }
                    .help("Next Match")
                    .disabled(totalMatches == 0)

                    Button {
                        isFindBarVisible = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .help("Close Find Bar")
                }
                .padding(.vertical, 4)
            }
            
            TextEditor(text: $entry.body)
                .font(.system(size: CGFloat(bodyPointSize)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onChange(of: entry) {
            appState.scheduleSave()
        }
        .onAppear { isTitleFocused = true }
        // Keyboard shortcuts for Find
        .overlay(
            Group {
                Button("") { isFindBarVisible = true; isFindFocused = true }
                    .keyboardShortcut("f", modifiers: [.command])
                    .opacity(0)
                Button("") { goToNextMatch() }
                    .keyboardShortcut(.return, modifiers: [])
                    .opacity(0)
                Button("") { goToPreviousMatch() }
                    .keyboardShortcut(.return, modifiers: [.shift])
                    .opacity(0)
            }
        )
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


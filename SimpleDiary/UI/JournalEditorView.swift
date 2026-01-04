import SwiftUI
import MarkdownUI
import Combine // Using RichTextView for search highlighting

struct JournalEditorView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var appState: DiaryAppState
    @Binding var entry: JournalEntry
    @FocusState private var isTitleFocused: Bool
    @State private var isPreviewMode: Bool = false
    
    // Persist the editor font size across launches
    @AppStorage("editorBodyPointSize") private var bodyPointSize: Double = 17

    // Find bar state
    @State private var isFindBarVisible: Bool = false
    @State private var findQuery: String = ""
    @FocusState private var isFindFocused: Bool
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    @State private var highlights: [NSRange] = []
    @State private var selectedRange: NSRange? = nil

    private func updateMatches() {
        let text = entry.body as NSString
        let query = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reset state when query is empty
        guard !query.isEmpty else {
            highlights = []
            totalMatches = 0
            currentMatchIndex = 0
            selectedRange = nil
            return
        }

        var ranges: [NSRange] = []
        let lowerText = text.lowercased
        let lowerQuery = query.lowercased()
        var searchRange = NSRange(location: 0, length: text.length)
        while true {
            let found = (lowerText as NSString).range(of: lowerQuery, options: [], range: searchRange)
            if found.location == NSNotFound { break }
            ranges.append(found)
            let nextLocation = found.location + max(found.length, 1)
            if nextLocation >= text.length { break }
            searchRange = NSRange(location: nextLocation, length: text.length - nextLocation)
        }

        highlights = ranges
        totalMatches = ranges.count
        currentMatchIndex = min(max(currentMatchIndex, 0), max(totalMatches - 1, 0))
        // Update selectedRange to the current match if available
        if totalMatches > 0, currentMatchIndex < ranges.count {
            selectedRange = ranges[currentMatchIndex]
        } else {
            selectedRange = nil
        }
    }

    private func goToNextMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
        if currentMatchIndex < highlights.count {
            selectedRange = highlights[currentMatchIndex]
        }
    }

    private func goToPreviousMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
        if currentMatchIndex < highlights.count {
            selectedRange = highlights[currentMatchIndex]
        }
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
            
            if !isPreviewMode && isFindBarVisible {
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
            
            if isPreviewMode {
                ScrollView {
                    MarkdownWithMathView(source: entry.body, bodyPointSize: CGFloat(bodyPointSize))
                        .padding(.vertical, 4)
                        .textSelection(.enabled)
                }
            } else {
                RichTextView(text: $entry.body, highlights: highlights, selectedRange: $selectedRange)
                    .font(.system(size: CGFloat(bodyPointSize)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: entry.body) { updateMatches() }
            }
        }
        .padding()
        .onChange(of: entry) { _, _ in
            appState.scheduleSave()
        }
        .onChange(of: isPreviewMode) { _, newValue in
            if newValue { isFindBarVisible = false }
        }
        .onAppear { isTitleFocused = true }
        // Keyboard shortcuts for Find
        .overlay(
            Group {
                Button("") { if !isPreviewMode { isFindBarVisible = true; isFindFocused = true } }
                    .keyboardShortcut("f", modifiers: [.command])
                    .opacity(0)
                Button("") { goToNextMatch() }
                    .keyboardShortcut(.return, modifiers: [])
                    .opacity(0)
                Button("") { goToPreviousMatch() }
                    .keyboardShortcut(.return, modifiers: [.shift])
                    .opacity(0)
                // Clear find query with Escape when find bar is visible
                if isFindBarVisible {
                    Button("") {
                        // Clear the search text and reset matches
                        findQuery = ""
                        updateMatches()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .opacity(0)
                }
            }
        )
        .toolbar {
            ToolbarItemGroup {
                Picker("Mode", selection: $isPreviewMode) {
                    Text("Edit").tag(false)
                    Text("Preview").tag(true)
                }
                .pickerStyle(.segmented)
                .help("Toggle between editing and Markdown preview")

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

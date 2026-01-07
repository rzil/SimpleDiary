import SwiftUI
import MarkdownUI

struct JournalEditorView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var appState: DiaryAppState
    @Binding var entry: JournalEntry
    @State private var loadedEntryID: JournalEntry.ID? = nil
    @Environment(\.undoManager) private var undoManager

    @FocusState private var isTitleFocused: Bool
    @State private var isPreviewMode: Bool = false

    // Persist the editor font size across launches
    @AppStorage("editorBodyPointSize") private var bodyPointSize: Double = 17

    // NEW: Attributed text editor state
    @State private var attributedBody: AttributedString = ""
    @State private var selection: AttributedTextSelection = AttributedTextSelection()

    // Find bar state
    @State private var isFindBarVisible: Bool = false
    @State private var findQuery: String = ""
    @FocusState private var isFindFocused: Bool
    @State private var currentMatchIndex: Int = 0
    @State private var matches: [Range<String.Index>] = []

    private var totalMatches: Int { matches.count }

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
                findBar
            }

            ZStack(alignment: .topLeading) {
                // Keep the editor alive to preserve undo stack
                TextEditor(text: $attributedBody, selection: $selection)
                    .font(.system(size: CGFloat(bodyPointSize)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(isPreviewMode)
                    .allowsHitTesting(!isPreviewMode)
                    .opacity(isPreviewMode ? 0 : 1)
                    .onChange(of: attributedBody) { _, newValue in
                        // Skip programmatic updates while preview is shown to avoid undo glitches
                        guard !isPreviewMode else { return }
                        // Push edits back into your stored String
                        let newPlain = String(newValue.characters)
                        if entry.body != newPlain {
                            entry.body = newPlain
                            appState.scheduleSave()
                        }
                        // Recompute matches/highlights while typing
                        updateMatchesAndHighlights(keepCurrentIndex: true)
                    }

                // Overlay Markdown preview when enabled
                if isPreviewMode {
                    ScrollView {
                        MarkdownWithMathView(source: entry.body)
                            .padding(.vertical, 4)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding()
        .onChange(of: entry) { _, _ in
            // Title/date/body changes
            appState.scheduleSave()
        }
        .onChange(of: isPreviewMode) { _, newValue in
            if newValue { isFindBarVisible = false }
        }
        .onAppear {
            isTitleFocused = true
            loadedEntryID = entry.id
            attributedBody = AttributedString(entry.body)
            updateMatchesAndHighlights(keepCurrentIndex: false)
        }
        .onChange(of: entry.id) { _, newID in
            // Switching to a different diary entry: refresh editor state
            loadedEntryID = newID
            attributedBody = AttributedString(entry.body)
            selection = AttributedTextSelection() // optional reset
            updateMatchesAndHighlights(keepCurrentIndex: false)
        }
        // Keyboard shortcuts for Find
        .overlay(findKeyboardShortcuts)
        .toolbar { editorToolbar }
    }

    // MARK: - Find bar UI

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find", text: $findQuery)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 200)
                .focused($isFindFocused)
                .onSubmit { goToNextMatch() }
                .onChange(of: findQuery) { _, _ in
                    updateMatchesAndHighlights(keepCurrentIndex: false)
                }
                .onAppear {
                    updateMatchesAndHighlights(keepCurrentIndex: false)
                }

            // Clear search text
            Button {
                findQuery = ""
                updateMatchesAndHighlights(keepCurrentIndex: false)
                isFindFocused = true
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear Search")
            .disabled(findQuery.isEmpty)

            if totalMatches > 0 {
                Text("\(currentMatchIndex + 1) of \(totalMatches)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: goToPreviousMatch) { Image(systemName: "chevron.up") }
                .help("Previous Match")
                .disabled(totalMatches == 0)

            Button(action: goToNextMatch) { Image(systemName: "chevron.down") }
                .help("Next Match")
                .disabled(totalMatches == 0)

            Button {
                isFindBarVisible = false
                // Optional: clear highlights when closing
                // findQuery = ""
                // updateMatchesAndHighlights(keepCurrentIndex: false)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .help("Close Find Bar")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Keyboard shortcuts overlay

    private var findKeyboardShortcuts: some View {
        Group {
            Button("") {
                if !isPreviewMode {
                    isFindBarVisible = true
                    isFindFocused = true
                }
            }
            .keyboardShortcut("f", modifiers: [.command])
            .opacity(0)

            Button("") { goToNextMatch() }
                .keyboardShortcut(.return, modifiers: [])
                .opacity(0)

            Button("") { goToPreviousMatch() }
                .keyboardShortcut(.return, modifiers: [.shift])
                .opacity(0)

            if isFindBarVisible {
                Button("") {
                    findQuery = ""
                    updateMatchesAndHighlights(keepCurrentIndex: false)
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
            }
        }
    }

    // MARK: - Toolbar

    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Picker("Mode", selection: $isPreviewMode) {
                Text("Edit").tag(false)
                Text("Preview").tag(true)
            }
            .pickerStyle(.segmented)
            .help("Toggle between editing and Markdown preview")

            Button {
                bodyPointSize = max(bodyPointSize - 1, 10)
            } label: { Image(systemName: "textformat.size.smaller") }
                .help("Decrease Text Size (Cmd -)")
                .keyboardShortcut("-", modifiers: [.command])

            Button {
                bodyPointSize = 17
            } label: { Image(systemName: "textformat.size") }
                .help("Actual Size (Cmd 0)")
                .keyboardShortcut("0", modifiers: [.command])

            Button {
                bodyPointSize = min(bodyPointSize + 1, 36)
            } label: { Image(systemName: "textformat.size.larger") }
                .help("Increase Text Size (Cmd +)")
                .keyboardShortcut("=", modifiers: [.command])
        }
    }

    // MARK: - Find logic (String ranges -> Attributed highlights + selection)

    private func updateMatchesAndHighlights(keepCurrentIndex: Bool) {
        let plain = entry.body
        let query = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            matches = []
            currentMatchIndex = 0
            // Clear highlights by resetting to plain
            attributedBody = AttributedString(plain)
            return
        }

        // Find all matches (case-insensitive) as String ranges
        let lowerPlain = plain.lowercased()
        let lowerQuery = query.lowercased()

        var foundRanges: [Range<String.Index>] = []
        var searchStart = lowerPlain.startIndex

        while searchStart < lowerPlain.endIndex,
              let r = lowerPlain.range(of: lowerQuery, range: searchStart..<lowerPlain.endIndex) {
            // Map range back to original String indices (same offsets)
            let startOffset = lowerPlain.distance(from: lowerPlain.startIndex, to: r.lowerBound)
            let endOffset   = lowerPlain.distance(from: lowerPlain.startIndex, to: r.upperBound)

            let origStart = plain.index(plain.startIndex, offsetBy: startOffset)
            let origEnd   = plain.index(plain.startIndex, offsetBy: endOffset)
            foundRanges.append(origStart..<origEnd)

            searchStart = r.upperBound
        }

        matches = foundRanges

        if keepCurrentIndex {
            currentMatchIndex = min(max(currentMatchIndex, 0), max(matches.count - 1, 0))
        } else {
            currentMatchIndex = 0
        }

        // Rebuild attributed body and apply highlight attributes.
        // (If you want to preserve user formatting, we’d do this differently.)
        var newAttributed = AttributedString(plain)

        for (i, r) in matches.enumerated() {
            guard
                let aStart = AttributedString.Index(r.lowerBound, within: newAttributed),
                let aEnd = AttributedString.Index(r.upperBound, within: newAttributed)
            else { continue }

            let ar = aStart..<aEnd

            // “All matches” highlight
            newAttributed[ar].backgroundColor = Color.yellow.opacity(0.25)

            // Current match emphasis
            if i == currentMatchIndex {
                newAttributed[ar].backgroundColor = Color.yellow.opacity(0.55)
                newAttributed[ar].underlineStyle = .single
            }
        }

        attributedBody = newAttributed

        // Update the editor selection to the current match range
        if totalMatches > 0, currentMatchIndex < matches.count {
            setEditorSelection(to: matches[currentMatchIndex])
        }
    }

    private func setEditorSelection(to stringRange: Range<String.Index>) {
        // Convert String range -> AttributedString range
        guard
            let aStart = AttributedString.Index(stringRange.lowerBound, within: attributedBody),
            let aEnd = AttributedString.Index(stringRange.upperBound, within: attributedBody)
        else { return }

        let ar = aStart..<aEnd
        selection = AttributedTextSelection(range: ar) // Apple API  [oai_citation:1‡Apple Developer](https://developer.apple.com/documentation/swiftui/attributedtextselection?utm_source=chatgpt.com)
    }

    private func goToNextMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
        updateMatchesAndHighlights(keepCurrentIndex: true)
    }

    private func goToPreviousMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
        updateMatchesAndHighlights(keepCurrentIndex: true)
    }
}


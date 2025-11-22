
import SwiftUI

struct JournalEditorView: View {
    @EnvironmentObject var store: JournalStore
    @Binding var entry: JournalEntry

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
            store.save()
        }
    }
}

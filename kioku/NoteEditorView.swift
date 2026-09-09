import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note

    var body: some View {
        VStack(spacing: 0) {
            TextField("Título", text: $note.title)
                .font(.title2.bold())
                .textFieldStyle(.plain)
                .padding()
                .onChange(of: note.title) { note.updatedAt = .now }

            Divider()

            TextEditor(text: $note.body)
                .font(.custom("Yomogi-Regular", size: 17))
                .padding(.horizontal, 12)
                .scrollContentBackground(.hidden)
                .onChange(of: note.body) { note.updatedAt = .now }

            Divider()

            TextField("tags separados por coma", text: $note.tags)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
                .padding(8)
                .onChange(of: note.tags) { note.updatedAt = .now }
        }
    }
}

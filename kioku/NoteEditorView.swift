import SwiftUI

/// La nota en la ventana principal: la misma tarjeta de papel del deck flotante,
/// más la fila de tags que ahí no cabe.
struct NoteEditorView: View {
    @Bindable var note: Note
    var onClose: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            StickyNoteView(note: note, onClose: onClose, onDelete: onDelete)

            Divider().opacity(0.25)

            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(note.palette.ink.opacity(0.4))
                TextField("tags separados por coma", text: $note.tags)
                    .font(Ink.body(12))
                    .foregroundStyle(note.palette.ink.opacity(0.75))
                    .textFieldStyle(.plain)
                    .onChange(of: note.tags) { note.updatedAt = .now }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(note.palette.paper)
        .animation(.easeInOut(duration: 0.25), value: note.colorHex)
    }
}

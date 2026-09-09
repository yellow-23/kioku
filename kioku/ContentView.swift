import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]) private var notes: [Note]

    @State private var searchText = ""
    @State private var selectedNote: Note?

    init() {}

    var filteredNotes: [Note] {
        let base = notes.filter {
            searchText.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted { $0.pinned && !$1.pinned }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedNote) {
                ForEach(filteredNotes) { note in
                    NoteRow(note: note)
                        .tag(note)
                        .swipeActions(edge: .leading) {
                            Button {
                                togglePin(note)
                            } label: {
                                Label(note.pinned ? "Despin" : "Pin", systemImage: note.pinned ? "pin.slash" : "pin")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(note)
                            } label: {
                                Label("Borrar", systemImage: "trash")
                            }
                        }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar notas o #tag")
            .navigationTitle("Kioku")
            .toolbar {
                ToolbarItem {
                    Button(action: addNote) {
                        Label("Nueva nota", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        } detail: {
            if let note = selectedNote {
                NoteEditorView(note: note)
                    .id(note.persistentModelID)
            } else {
                Text("Selecciona o crea una nota")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addNote() {
        let note = Note()
        context.insert(note)
        selectedNote = note
    }

    private func togglePin(_ note: Note) {
        note.pinned.toggle()
        note.updatedAt = .now
    }

    private func delete(_ note: Note) {
        if selectedNote == note { selectedNote = nil }
        context.delete(note)
    }
}

private struct NoteRow: View {
    @Bindable var note: Note

    var body: some View {
        HStack {
            if note.pinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Sin título" : note.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(note.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}

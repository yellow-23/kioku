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
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 340)
        } detail: {
            ZStack {
                Washi.desk.ignoresSafeArea()
                if let note = selectedNote {
                    NoteEditorView(note: note,
                                   onClose: { select(nil) },
                                   onDelete: { delete(note) })
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.28), radius: 20, x: 0, y: 10)
                        .frame(maxWidth: 760)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                        .id(note.persistentModelID)
                        .transition(.opacity.combined(with: .offset(y: 10)))
                } else {
                    EmptyDetail()
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.28), value: selectedNote?.persistentModelID)
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Buscar")
        .toolbar {
            ToolbarItem {
                Button(action: addNote) {
                    Label("Nueva nota", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        // barra transparente: la bandeja y el escritorio siguen por debajo
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationTitle("")
    }

    // MARK: Índice

    /// Un índice, no una lista de tarjetas: muestra de papel + título, sin
    /// contenedores. La nota fijada lleva el sello; es el único rojo de la app.
    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("記憶")
                        .font(Ink.body(24))
                        .foregroundStyle(Washi.ink)
                    Text("\(notes.count)")
                        .font(Ink.body(12))
                        .foregroundStyle(Washi.inkSoft)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 14)

                ForEach(filteredNotes) { note in
                    Button { select(note) } label: {
                        IndexRow(note: note, isSelected: selectedNote == note)
                    }
                    .buttonStyle(.plain)
                        .contextMenu {
                            Button(note.pinned ? "Desfijar" : "Fijar") { togglePin(note) }
                            Divider()
                            Button("Borrar", role: .destructive) { delete(note) }
                        }
                        .transition(.opacity)
                }

                if filteredNotes.isEmpty && !searchText.isEmpty {
                    Text("Nada con 「\(searchText)」")
                        .font(Ink.body(13))
                        .foregroundStyle(Washi.inkSoft)
                        .padding(12)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.smooth(duration: 0.3), value: filteredNotes.map(\.persistentModelID))
        }
        .scrollContentBackground(.hidden)
        // una bandeja un tono más clara que el escritorio
        // hasta arriba, bajo los semáforos: si no, queda un escalón en la barra de título
        .background { Washi.deskRaised.ignoresSafeArea() }
        // ↑↓ recorren el índice, como en cualquier lista de Mac
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { step(-1) }
        .onKeyPress(.downArrow) { step(1) }
    }

    // MARK: Acciones

    private func select(_ note: Note?) {
        selectedNote = note
    }

    private func step(_ delta: Int) -> KeyPress.Result {
        let list = filteredNotes
        guard !list.isEmpty else { return .ignored }
        let i = selectedNote.flatMap { list.firstIndex(of: $0) }.map { $0 + delta } ?? 0
        select(list[min(max(0, i), list.count - 1)])
        return .handled
    }

    private func addNote() {
        let note = Note()
        note.colorHex = NoteColors.palette.randomElement()!
        context.insert(note)
        select(note)
    }

    private func togglePin(_ note: Note) {
        withAnimation(.smooth(duration: 0.3)) { note.pinned.toggle() }
        note.updatedAt = .now
    }

    private func delete(_ note: Note) {
        if selectedNote == note { select(nil) }
        withAnimation(.smooth(duration: 0.3)) { context.delete(note) }
    }
}

// MARK: - Fila

private struct IndexRow: View {
    @Bindable var note: Note
    let isSelected: Bool

    @State private var hovering = false

    /// Si la nota no tiene título, el título ya es la primera línea del cuerpo:
    /// el adelanto muestra la que sigue.
    private var preview: String {
        let lines = note.body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let untitled = note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (untitled ? Array(lines.dropFirst()) : lines).first ?? ""
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            // muestra de papel, como un recorte de chiyogami
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(note.palette.paper)
                .overlay(RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .strokeBorder(Washi.ink.opacity(0.15), lineWidth: 0.5))
                .frame(width: isSelected ? 14 : 11, height: isSelected ? 14 : 11)
                .frame(width: 14)
                .rotationEffect(.degrees(isSelected ? -6 : 0))

            VStack(alignment: .leading, spacing: 1) {
                Text(note.displayTitle)
                    .font(Ink.body(14))
                    .foregroundStyle(isSelected ? Washi.ink : Washi.ink.opacity(0.82))
                    .lineLimit(1)
                if !preview.isEmpty {
                    Text(preview)
                        .font(Ink.body(11))
                        .foregroundStyle(Washi.inkSoft)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if note.pinned {
                Hanko()
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? note.palette.paper.opacity(0.16)
                      : (hovering ? Washi.ink.opacity(0.06) : .clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.18), value: hovering)
        .animation(.smooth(duration: 0.25), value: isSelected)
    }
}

/// El sello de nota fijada: 留 ("guardar, retener") en bermellón, un poco torcido,
/// como estampado a mano.
struct Hanko: View {
    var size: CGFloat = 17

    var body: some View {
        Text("留")
            .font(Ink.body(size * 0.64))
            .foregroundStyle(Washi.shuInk)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous).fill(Washi.shu))
            .rotationEffect(.degrees(-7))
            .help("Fijada")
    }
}

private struct EmptyDetail: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("記")
                .font(Ink.body(110))
                .foregroundStyle(Washi.ink.opacity(0.07))
            Text("Elige una nota del índice")
                .font(Ink.body(16))
                .foregroundStyle(Washi.inkSoft)
            Text("o ⌘N para escribir una nueva")
                .font(Ink.body(12))
                .foregroundStyle(Washi.inkSoft.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}

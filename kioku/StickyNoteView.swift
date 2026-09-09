import SwiftUI

struct StickyNoteView: View {
    @Bindable var note: Note
    var onClose: () -> Void
    var onDelete: () -> Void

    private var ink: Color { note.palette.ink }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Título", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(Ink.body(19))
                    .foregroundStyle(.black)
                Spacer(minLength: 6)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        note.pinned.toggle()
                    }
                } label: {
                    Image(systemName: note.pinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundStyle(ink.opacity(note.pinned ? 0.9 : 0.5))
                        .rotationEffect(.degrees(note.pinned ? -45 : 0))
                }
                .buttonStyle(SoftButtonStyle())
                .help(note.pinned ? "Desfijar" : "Fijar")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.5))
                }
                .buttonStyle(SoftButtonStyle())
                .help("Cerrar (Esc)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().opacity(0.3)

            TextEditor(text: $note.body)
                .font(Ink.body(17))
                .foregroundStyle(.black)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.top, 6)

            Divider().opacity(0.3)

            HStack(spacing: 0) {
                // 8 colores no entran junto a botones de texto en 280pt: puntos
                // chicos y la acción como ícono
                HStack(spacing: 5) {
                    ForEach(NoteColors.palette, id: \.self) { hex in
                        ColorDot(hex: hex, isSelected: note.colorHex == hex) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                note.colorHex = hex
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.75))
                }
                .buttonStyle(SoftButtonStyle())
                .help("Borrar (⌘⌫)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            note.palette.paper
                .overlay(alignment: .bottomTrailing) {
                    // 記 de "記憶" (kioku, memoria) — marca de agua sutil, guiño al nombre de la app
                    Text("記")
                        .font(Ink.body(92))
                        .foregroundStyle(.black.opacity(0.05))
                        .offset(x: 18, y: 22)
                        .allowsHitTesting(false)
                }
                .clipped()
        )
        .onChange(of: note.title) { note.updatedAt = .now }
        .onChange(of: note.body) { note.updatedAt = .now }
        .background {
            // atajos invisibles: Esc cierra, ⌘. cicla color, ⌘⌫ borra
            Group {
                Button("", action: onClose).keyboardShortcut(.escape, modifiers: [])
                Button("", action: cycleColor).keyboardShortcut(".", modifiers: .command)
                Button("", action: onDelete).keyboardShortcut(.delete, modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    private func cycleColor() {
        let palette = NoteColors.palette
        let currentIndex = palette.firstIndex(of: note.colorHex) ?? 0
        let next = palette[(currentIndex + 1) % palette.count]
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            note.colorHex = next
        }
    }
}

private struct ColorDot: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Circle()
            .fill(NoteColors.at(hex).paper)
            .frame(width: 13, height: 13)
            .overlay(
                Circle().stroke(.black.opacity(isSelected ? 0.45 : 0.08), lineWidth: isSelected ? 2 : 0.5)
            )
            .scaleEffect(isSelected ? 1.2 : (isHovered ? 1.15 : 1))
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
            .onHover { isHovered = $0 }
            .onTapGesture(perform: action)
    }
}

/// Feedback de hover/press consistente para botones de texto/ícono en toda la app.
struct SoftButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : (isHovered ? 0.75 : 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

#if os(macOS)
/// La nota abierta: sale de su propio tab y queda pegada al borde, con el tab
/// convertido en canaleta a la izquierda. Es lo que hace que se lea como que
/// crece del deck y no como una ventana que llega volando.
struct ExpandedNoteView: View {
    @Bindable var note: Note
    var onClose: () -> Void
    var onDelete: () -> Void

    private var noteShape: UnevenRoundedRectangle { edgeTabShape(radius: 14) }

    var body: some View {
        HStack(spacing: 0) {
            gutter
            StickyNoteView(note: note, onClose: onClose, onDelete: onDelete)
        }
        .frame(width: DeckGeom.editorWidth + DeckGeom.gutterWidth, height: DeckGeom.editorHeight)
        .background(
            noteShape
                .fill(note.palette.paper)
                .shadow(color: .black.opacity(0.34), radius: 28, x: -12, y: 12)
        )
        .clipShape(noteShape)
        .overlay(noteShape.strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5))
    }

    /// `rotationEffect` es transform de render, no de layout: la etiqueta rotada
    /// sigue midiendo su ancho sin rotar, así que el tinte se dimensiona aparte y
    /// la etiqueta se recorta adentro o el fondo se derrama sobre la nota.
    private var gutter: some View {
        Rectangle()
            .fill(note.palette.dash.opacity(0.20))
            .frame(width: DeckGeom.gutterWidth)
            .overlay {
                Text(note.displayTitle.uppercased())
                    .font(Ink.tabFont)
                    .tracking(Ink.tabTracking)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(note.palette.ink.opacity(0.7))
                    .frame(width: DeckGeom.editorHeight - 44)
                    .rotationEffect(.degrees(90))
            }
            .clipped()
            .overlay(alignment: .trailing) {
                EdgeLine()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(note.palette.ink.opacity(0.22))
                    .frame(width: 1)
            }
    }
}

/// La nota saliendo de su tab: un tramo corto desde el borde, una pizca de escala
/// anclada ahí y un fundido. Un slide de ancho completo se lee como ventana volando.
struct NotePull: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: hidden ? 40 : 0)
            .scaleEffect(hidden ? 0.965 : 1, anchor: .trailing)
            .opacity(hidden ? 0 : 1)
    }
}
#endif

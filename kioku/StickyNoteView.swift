import SwiftUI

struct StickyNoteView: View {
    @Bindable var note: Note
    var onClose: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Título", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(.custom("Yomogi-Regular", size: 19))
                Spacer()
                Text("Guardado")
                    .font(.caption2)
                    .foregroundStyle(.black.opacity(0.4))
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        note.pinned.toggle()
                    }
                } label: {
                    Image(systemName: note.pinned ? "pin.fill" : "pin")
                        .rotationEffect(.degrees(note.pinned ? -45 : 0))
                        .scaleEffect(note.pinned ? 1.15 : 1)
                }
                .buttonStyle(SoftButtonStyle())
            }
            .padding(12)

            Divider().opacity(0.3)

            TextEditor(text: $note.body)
                .font(.custom("Yomogi-Regular", size: 17))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.top, 6)

            Divider().opacity(0.3)

            HStack(spacing: 8) {
                ForEach(NoteColors.palette, id: \.self) { hex in
                    ColorDot(hex: hex, isSelected: note.colorHex == hex) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            note.colorHex = hex
                        }
                    }
                }

                Spacer()

                Button("Borrar", role: .destructive, action: onDelete)
                    .buttonStyle(SoftButtonStyle())
                    .font(.caption)
                    .foregroundStyle(.red)

                Button(note.completed ? "Reabrir" : "Completar") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        note.completed.toggle()
                    }
                }
                .buttonStyle(SoftButtonStyle())
                .font(.caption)

                Button("Cerrar", action: onClose)
                    .buttonStyle(SoftButtonStyle())
                    .font(.caption)
            }
            .padding(12)
        }
        .background(
            Color(hex: note.colorHex)
                .overlay(alignment: .bottomTrailing) {
                    // 記 de "記憶" (kioku, memoria) — marca de agua sutil, guiño al nombre de la app
                    Text("記")
                        .font(.custom("Yomogi-Regular", size: 92))
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
            .fill(Color(hex: hex))
            .frame(width: 16, height: 16)
            .overlay(
                Circle().stroke(.black.opacity(isSelected ? 0.4 : 0), lineWidth: 2)
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

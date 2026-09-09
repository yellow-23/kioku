#if os(macOS)
import SwiftUI
import SwiftData

struct TabStripView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Note.createdAt, order: .forward)]) private var notes: [Note]

    var onTapNote: (Note) -> Void

    init(onTapNote: @escaping (Note) -> Void) {
        self.onTapNote = onTapNote
    }

    @State private var isFanned = false
    @State private var pressedID: PersistentIdentifier?
    @State private var hoveredID: PersistentIdentifier?

    var body: some View {
        VStack(spacing: isFanned ? 6 : 3) {
            if notes.isEmpty && !isFanned {
                Capsule()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 5, height: 40)
            }

            ForEach(Array(notes.enumerated()), id: \.element.persistentModelID) { index, note in
                let id = note.persistentModelID
                let isHovered = isFanned && hoveredID == id
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: note.colorHex))
                    .frame(width: 7, height: 16)
                    .shadow(radius: isHovered ? 6 : 0)
                    // crece con scale, no con frame, así no reacomoda el layout ni empuja al mouse
                    .scaleEffect(pressedID == id ? 0.88 : (isHovered ? 3.2 : 1), anchor: .trailing)
                    .offset(x: isHovered ? -10 : 0)
                    .zIndex(isHovered ? 1 : 0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: hoveredID)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressedID)
                    // el pill visual es angosto (7pt); el área de hover/click es más ancha para que no cueste acertarle
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        guard isFanned else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            hoveredID = hovering ? id : (hoveredID == id ? nil : hoveredID)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in if isFanned { pressedID = id } }
                            .onEnded { _ in
                                pressedID = nil
                                if isFanned { onTapNote(note) }
                            }
                    )
            }

            if isFanned && hoveredID == nil {
                Button {
                    let note = Note()
                    note.colorHex = NoteColors.palette.randomElement()!
                    context.insert(note)
                    onTapNote(note)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(SoftButtonStyle())
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isFanned = hovering }
            if !hovering { hoveredID = nil }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: notes.count)
    }
}
#endif

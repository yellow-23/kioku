#if os(macOS)
import SwiftUI
import SwiftData
import Combine

final class DeckModel: ObservableObject {
    @Published var fanned = false
    /// Se incrementa para re-escalonar la animación de aparición del abanico.
    @Published var revealTick = 0
    @Published var openID: PersistentIdentifier?
    /// Abierta con un click: se queda hasta Esc. Abierta al pasar el mouse: se va
    /// sola cuando el puntero deja el deck.
    @Published var stickyOpen = false
    /// El tope de la nota en el momento en que se abrió. Se ancla acá y en ningún
    /// lado más: recalcularlo mientras se escribe el título la hace saltar.
    @Published var openedTop: CGFloat?
}

// MARK: - Raíz

struct TabStripView: View {
    @ObservedObject var deck: DeckModel
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Note.createdAt, order: .forward)]) private var notes: [Note]

    var onTapNote: (Note) -> Void
    var onHoverNote: (Note) -> Void
    var onDeleteNote: (Note) -> Void

    private var longestLabel: CGFloat {
        notes.map { DeckGeom.labelWidth($0.displayTitle) }.max() ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            let h = max(1, geo.size.height)
            let lay = DeckGeom.layout(panelHeight: h, count: max(1, notes.count),
                                      longestLabel: longestLabel)

            ZStack(alignment: .topTrailing) {
                if deck.fanned || h > lay.stackHeight {
                    FanColumn(deck: deck, notes: notes, layout: lay,
                              onTapNote: onTapNote, onHoverNote: onHoverNote,
                              onNewNote: newNote)
                        .padding(.top, fanTop(lay, panelHeight: h))
                }

                PillView(notes: notes)
                    .padding(.top, pillTop(panelHeight: h))
                    .padding(.trailing, 1)
                    .opacity(deck.fanned ? 0 : 1)
                    .animation(.easeInOut(duration: 0.20).delay(deck.fanned ? 0 : 0.12), value: deck.fanned)

                // Declarada al final: tapa el deck, a ras del borde de pantalla.
                if let id = deck.openID, let note = notes.first(where: { $0.persistentModelID == id }) {
                    ExpandedNoteView(note: note,
                                     onClose: {
                                         // dejarla no-fijada devuelve el deck al
                                         // cierre automático al alejar el mouse
                                         deck.stickyOpen = false
                                         deck.openedTop = nil
                                         withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                             deck.openID = nil
                                         }
                                     },
                                     onDelete: { onDeleteNote(note) })
                        .padding(.top, editorTop(lay, id: id, panelHeight: h))
                        .transition(.modifier(active: NotePull(hidden: true),
                                              identity: NotePull(hidden: false)))
                        .id(id)
                }
            }
            // Un ZStack sólo mide lo que su hijo más ancho, así que hay que decirle
            // que llene el panel o el deck queda despegado del borde.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.9), value: deck.fanned)
    }

    private func newNote() {
        let note = Note()
        note.colorHex = NoteColors.palette.randomElement()!
        context.insert(note)
        onTapNote(note)
    }

    /// Dónde va la píldora para cualquier alto de panel: en reposo el panel mide
    /// exactamente la píldora y esto es cero; en el panel alto cae en la misma
    /// posición de pantalla, así no se mueve cuando el panel crece a su alrededor.
    private func pillTop(panelHeight h: CGFloat) -> CGFloat {
        let pillH = DeckGeom.pillHeight(noteCount: max(1, notes.count))
        return max(0, h - pillH) / 2
    }

    private func fanTop(_ lay: DeckLayout, panelHeight h: CGFloat) -> CGFloat {
        let ideal = h / 2 - lay.stackHeight / 2
        return min(max(12, ideal), max(12, h - lay.stackHeight - 12))
    }

    /// La nota abierta queda a la altura de su propio tab, sin salirse de pantalla.
    private func editorTop(_ lay: DeckLayout, id: PersistentIdentifier, panelHeight h: CGFloat) -> CGFloat {
        if let top = deck.openedTop { return top }
        let idx = notes.firstIndex { $0.persistentModelID == id } ?? 0
        let noteH = DeckGeom.editorHeight
        let fTop = fanTop(lay, panelHeight: h)
        let strip = idx == lay.count - 1 ? lay.itemHeight : lay.pitch
        let stripCenter = fTop + CGFloat(idx) * lay.pitch + strip / 2
        let resolved = min(max(10, stripCenter - noteH / 2), max(10, h - noteH - 10))
        DispatchQueue.main.async { deck.openedTop = resolved }
        return resolved
    }
}

// MARK: - Píldora (en reposo)

struct PillView: View {
    let notes: [Note]

    private var shown: [Note] { Array(notes.prefix(DeckGeom.maxDashes)) }
    private var overflow: Int { max(0, notes.count - DeckGeom.maxDashes) }

    var body: some View {
        VStack(spacing: DeckGeom.dashGap) {
            if notes.isEmpty { dash(Color.secondary.opacity(0.4)) }
            ForEach(shown) { dash($0.palette.paper) }
            if overflow > 0 { dash(Color.secondary.opacity(0.5)) }
        }
        .padding(.vertical, DeckGeom.pillPad)
        .frame(width: DeckGeom.pillWidth)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 6, x: -2, y: 1)
        )
    }

    private func dash(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(color)
            .frame(width: DeckGeom.dashWidth, height: DeckGeom.dashHeight)
    }
}

// MARK: - Abanico

struct FanColumn: View {
    @ObservedObject var deck: DeckModel
    let notes: [Note]
    let layout: DeckLayout
    var onTapNote: (Note) -> Void
    var onHoverNote: (Note) -> Void
    var onNewNote: () -> Void

    @State private var appeared = false
    @State private var hoverWork: DispatchWorkItem?

    private var isRevealed: Bool { deck.fanned && appeared }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if layout.overflows {
                    ScrollView(.vertical, showsIndicators: false) {
                        stack.padding(.vertical, 4)
                    }
                    .frame(height: layout.cap)
                    .scrollClipDisabled()
                } else {
                    stack
                }
            }
            .overlay(alignment: .trailing) { spine }

        }
        .onAppear { DispatchQueue.main.async { appeared = true } }
        .onChange(of: deck.revealTick) { _, _ in
            appeared = false
            DispatchQueue.main.async { appeared = true }
        }
        .onChange(of: deck.fanned) { _, open in
            if !open { appeared = false; cancelHoverOpen() }
        }
    }

    /// El solape sale del spacing negativo del VStack — layout real, así las áreas
    /// de click siguen a los tabs. Con `.offset` se dibujarían bien pero los clicks
    /// quedarían arriba. El orden de pintado es el de declaración: cada tab tapa al
    /// anterior, que es justo la teja que queremos. Un `zIndex` por tab NO es
    /// equivalente: reordena vecinos y rompe el solape.
    private var stack: some View {
        let total = notes.count + 1
        return VStack(spacing: layout.spacing) {
            if notes.isEmpty {
                EmptyTab(height: layout.itemHeight, strip: layout.pitch, action: onNewNote)
                    .staged(index: 0, total: 2, revealed: isRevealed)
            }
            ForEach(Array(notes.enumerated()), id: \.element.persistentModelID) { idx, note in
                VerticalTab(note: note,
                            isOpen: deck.openID == note.persistentModelID,
                            height: layout.itemHeight,
                            strip: layout.pitch,
                            action: { cancelHoverOpen(); onTapNote(note) },
                            onHoverChanged: { inside in
                                if inside { scheduleHoverOpen(note) } else { cancelHoverOpen() }
                            })
                    .staged(index: idx, total: total, revealed: isRevealed)
            }
            PlusButton(action: onNewNote)
                .padding(.top, DeckGeom.plusGap - layout.spacing)
                .staged(index: notes.count, total: total, revealed: isRevealed)
        }
        .frame(width: DeckGeom.tabWidth)
    }

    /// El puntero tiene que posarse un momento sobre el tab, o barrer el deck abre
    /// una nota por cada tab de paso.
    private func scheduleHoverOpen(_ note: Note) {
        hoverWork?.cancel()
        let work = DispatchWorkItem {
            guard deck.fanned, deck.openID != note.persistentModelID else { return }
            onHoverNote(note)
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func cancelHoverOpen() { hoverWork?.cancel(); hoverWork = nil }

    /// La línea punteada de la que cuelga el deck, contra el borde de pantalla.
    private var spine: some View {
        EdgeLine()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .foregroundStyle(Color.white.opacity(0.35))
            .frame(width: 1, height: min(layout.stackHeight + 26, layout.cap))
            .padding(.trailing, 3)
            .allowsHitTesting(false)
    }
}

struct EdgeLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        return p
    }
}

// MARK: - Tabs

/// Un tab guarda su color y lleva su etiqueta de costado.
///
/// Los tabs se solapan, así que la etiqueta va pegada al tope — la parte que queda
/// descubierta.
struct VerticalTab: View {
    let note: Note
    let isOpen: Bool
    let height: CGFloat
    let strip: CGFloat          // lo que de este tab no tapa el siguiente
    let action: () -> Void
    var onHoverChanged: (Bool) -> Void = { _ in }

    @State private var hovering = false

    /// En reposo la etiqueta entra en la franja descubierta; al pasar el mouse el
    /// tab se levanta sobre sus vecinos y la etiqueta usa el alto completo, así se
    /// lee el título entero de costado en vez de truncado.
    private var labelBox: CGFloat { hovering ? height : strip }

    var body: some View {
        ZStack(alignment: .top) {
            edgeTabShape()
                .fill(note.palette.paper)
                // Fijada: contorno saturado en vez de una marca chica. El borde
                // se ve entero aunque el tab siguiente tape la mitad del tab.
                .overlay {
                    if note.pinned {
                        edgeTabShape().strokeBorder(note.palette.dash, lineWidth: 2)
                    }
                }
                .shadow(color: .black.opacity(isOpen || hovering ? 0.32 : 0.22),
                        radius: isOpen || hovering ? 9 : 6, x: -3, y: 2)
            Text(note.displayTitle.uppercased())
                .font(Ink.tabFont)
                .tracking(Ink.tabTracking)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(note.palette.ink.opacity(note.pinned || hovering ? 1 : 0.8))
                .frame(width: max(20, labelBox - DeckGeom.labelInset), height: DeckGeom.tabWidth)
                .rotationEffect(.degrees(90))
                .frame(width: DeckGeom.tabWidth, height: labelBox)
                .offset(x: -DeckGeom.bleed / 2)
        }
        .frame(width: DeckGeom.tabWidth + DeckGeom.bleed, height: height, alignment: .top)
        .rotationEffect(.degrees(DeckGeom.leanDegrees), anchor: .trailing)
        .offset(x: DeckGeom.bleed)
        .frame(width: DeckGeom.tabWidth)
        // asoma hacia adentro para que se vea que está levantado
        .offset(x: hovering ? -10 : 0)
        // Caja fija: el frame de acá no se mueve con el hover, así el área que
        // detecta el mouse no persigue al tab mientras se desliza. Sin esto el
        // puntero quedaba fuera apenas empezaba la animación, el tab volvía, y
        // los dos vecinos se turnaban el hover a 60 fps.
        .frame(width: DeckGeom.tabWidth, height: height, alignment: .top)
        // En reposo sólo escucha su franja visible — los frames se solapan y si
        // no, el tab de arriba robaría el hover del de abajo. Ya levantado
        // escucha todo su alto, que es lo que se ve.
        .contentShape(TabHitBox(height: hovering ? height : strip))
        // sólo el tab bajo el mouse sube; darle zIndex a todos reordena vecinos
        // y rompe el solape de tejas
        .zIndex(hovering ? 900 : 0)
        .onTapGesture(perform: action)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isOpen)
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: hovering)
        .help(note.displayTitle)
    }
}

/// El rectángulo que escucha el mouse: pegado al tope y de alto variable.
private struct TabHitBox: Shape {
    let height: CGFloat
    func path(in r: CGRect) -> Path {
        Path(CGRect(x: r.minX, y: r.minY, width: r.width, height: min(height, r.height)))
    }
}

struct EmptyTab: View {
    let height: CGFloat
    let strip: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                edgeTabShape().fill(.ultraThinMaterial)
                Text("NUEVA")
                    .font(Ink.tabFont)
                    .tracking(Ink.tabTracking)
                    .foregroundStyle(.secondary)
                    .frame(width: max(20, strip - DeckGeom.labelInset), height: DeckGeom.tabWidth)
                    .rotationEffect(.degrees(90))
                    .frame(width: DeckGeom.tabWidth, height: strip)
            }
            .frame(width: DeckGeom.tabWidth, height: height, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(TabPressStyle())
    }
}

struct PlusButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.75))
                .frame(width: DeckGeom.plusSize, height: DeckGeom.plusSize)
                .background(Circle().fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.22), radius: 5, y: 1))
                .scaleEffect(hovering ? 1.08 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help("Nueva nota")
    }
}

// MARK: - Aparición escalonada

private struct Staged: ViewModifier {
    let index: Int
    let totalCount: Int
    let revealed: Bool

    func body(content: Content) -> some View {
        let delay = revealed
            ? Double(index) * 0.042
            : Double(max(0, totalCount - 1 - index)) * 0.030
        content
            .offset(x: revealed ? 0 : DeckGeom.tabWidth + 24)
            .opacity(revealed ? 1 : 0)
            .animation(.spring(response: 0.34, dampingFraction: 0.84).delay(delay), value: revealed)
    }
}

private extension View {
    func staged(index: Int, total: Int = 1, revealed: Bool) -> some View {
        modifier(Staged(index: index, totalCount: total, revealed: revealed))
    }
}

struct TabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
#endif

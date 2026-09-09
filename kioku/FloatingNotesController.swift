#if os(macOS)
import AppKit
import SwiftUI
import SwiftData

/// Un panel .borderless devuelve canBecomeKey = false por defecto, así que
/// makeKeyAndOrderFront no lo hace key y el teclado nunca llega al contenido.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Con la app inactiva (LSUIElement), el primer click en una ventana se consume
/// para activarla y no llega al contenido. Esto lo entrega directo a SwiftUI.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// El panel del deck es mucho más ancho que los tabs: la zona vacía tiene que
/// dejar pasar los clicks a la app de abajo, y el tracking area es lo que avisa
/// cuándo abrir y cerrar el abanico.
final class DeckContentView: NSView {
    weak var controller: FloatingNotesController?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for a in trackingAreas { removeTrackingArea(a) }
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { controller?.pointerEntered() }
    override func mouseExited(with event: NSEvent) { controller?.pointerExited() }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit    // nunca comerse un click sobre el vacío
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class FloatingNotesController: NSObject {
    static let shared = FloatingNotesController()

    private var stripPanel: NSPanel?
    private let deck = DeckModel()
    private var exitWork: DispatchWorkItem?
    private var shrinkWork: DispatchWorkItem?
    /// Verdadero entre el resize del panel y el despliegue de los tabs: sin esto,
    /// los mouseEntered que dispara el propio resize reabren el abanico en loop.
    private var growing = false
    private var watchTimer: Timer?

    var isVisible: Bool { stripPanel != nil }

    func hideStrip() {
        stopWatch()
        deck.openID = nil
        deck.fanned = false
        stripPanel?.orderOut(nil)
        stripPanel = nil
    }

    func showStrip() {
        guard stripPanel == nil, let screen = NSScreen.main else { return }

        let container = DeckContentView()
        container.controller = self
        container.autoresizingMask = [.width, .height]

        let root = TabStripView(deck: deck,
                                onTapNote: { [weak self] note in self?.openNote(note, sticky: true) },
                                onHoverNote: { [weak self] note in self?.openNote(note, sticky: false) },
                                onDeleteNote: { [weak self] note in
                                    self?.deleteWithUndo(note: note, id: note.persistentModelID)
                                })
        let hosting = FirstMouseHostingView(rootView: root.modelContainer(AppContainer.shared))
        hosting.autoresizingMask = [.width, .height]
        // sin esto, NSHostingView reajusta la ventana al tamaño intrínseco del contenido
        hosting.sizingOptions = []
        container.addSubview(hosting)

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: DeckGeom.edgeWidth, height: 100),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        // las sombras las dibuja cada tab en SwiftUI; la del panel sería un rectángulo
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.contentView = container
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.alphaValue = 0
        stripPanel = panel

        layoutStrip()
        hosting.frame = container.bounds
        let rest = panel.frame
        // arranca fuera de pantalla y se desliza hacia adentro
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX + 30, y: rest.minY))
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            // setFrameOrigin no es animatable en NSWindow; setFrame(_:display:) sí lo es
            panel.animator().setFrame(rest, display: true)
        }
    }

    /// En reposo el panel es sólo la franja de la píldora, para no comerse media
    /// pantalla; abierto ocupa el alto útil y el ancho que necesitan tabs y tarjeta.
    private func layoutStrip() {
        guard let panel = stripPanel, let screen = NSScreen.main else { return }
        let full = screen.frame
        let vis = screen.visibleFrame

        let frame: NSRect
        if deck.fanned {
            frame = NSRect(x: full.maxX - DeckGeom.panelWidth, y: vis.minY,
                           width: DeckGeom.panelWidth, height: vis.height)
        } else {
            let count = (try? AppContainer.shared.mainContext.fetchCount(FetchDescriptor<Note>())) ?? 1
            let h = DeckGeom.pillHeight(noteCount: max(1, count))
            frame = NSRect(x: full.maxX - DeckGeom.edgeWidth,
                           y: round(vis.midY - h / 2),
                           width: DeckGeom.edgeWidth, height: h)
        }
        panel.setFrame(frame, display: true, animate: false)
    }

    func pointerEntered() {
        exitWork?.cancel(); exitWork = nil
        shrinkWork?.cancel(); shrinkWork = nil
        guard !deck.fanned, !growing else { return }

        // El panel tiene que estar en su tamaño final *y renderizado* antes de que
        // los tabs entren. `main.async` no alcanza: SwiftUI junta el resize con el
        // cambio de estado en una sola pasada y anima el ancho del contenedor,
        // arrastrando el deck por la pantalla. Dos frames los separan.
        growing = true
        fannedFrameNow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 / 60.0) { [weak self] in
            guard let self else { return }
            self.growing = false
            guard let panel = self.stripPanel, panel.frame.contains(NSEvent.mouseLocation) else {
                self.layoutStrip()   // el puntero se fue durante el resize
                return
            }
            self.deck.fanned = true
            self.deck.revealTick &+= 1
            self.startWatch()
        }
    }

    /// El panel abierto es mucho más ancho que el deck, así que el tracking area no
    /// avisa cuando el puntero se aleja de los tabs: se compara contra la franja
    /// caliente. Sondear el puntero evita depender de eventos mouse-moved globales.
    private func startWatch() {
        guard watchTimer == nil else { return }
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.deck.fanned else { return }
            guard !self.deck.stickyOpen else { return }
            if !self.hotZone.contains(NSEvent.mouseLocation) { self.collapse() }
        }
    }

    private func stopWatch() { watchTimer?.invalidate(); watchTimer = nil }

    /// La banda del borde en la que el deck se mantiene abierto: los tabs, o la
    /// nota entera si hay una asomada.
    private var hotZone: NSRect {
        guard let panel = stripPanel else { return .zero }
        let f = panel.frame
        let w = deck.openID != nil
            ? DeckGeom.editorWidth + DeckGeom.gutterWidth + 24
            : DeckGeom.fanWidth + 24
        return NSRect(x: f.maxX - w, y: f.minY, width: w, height: f.height)
    }

    private func collapse() {
        stopWatch()
        closeNote()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) { deck.fanned = false }
        let shrink = DispatchWorkItem { [weak self] in
            guard let self, !self.deck.fanned else { return }
            self.layoutStrip()
        }
        shrinkWork = shrink
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: shrink)
    }

    /// El marco abierto, sin tocar todavía el estado del deck.
    private func fannedFrameNow() {
        guard let panel = stripPanel, let screen = NSScreen.main else { return }
        panel.setFrame(NSRect(x: screen.frame.maxX - DeckGeom.panelWidth,
                              y: screen.visibleFrame.minY,
                              width: DeckGeom.panelWidth,
                              height: screen.visibleFrame.height),
                       display: true, animate: false)
    }

    func pointerExited() {
        guard !deck.stickyOpen else { return }   // la nota fijada con click se cierra con Esc
        guard deck.fanned || growing else { return }
        // El tracking area dispara de más durante los resizes: confirmá que el
        // puntero de verdad se fue.
        exitWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.deck.fanned, !self.hotZone.contains(NSEvent.mouseLocation) else { return }
            self.collapse()
        }
        exitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    /// La nota se abre dentro del propio panel del deck: sale de su tab, no de
    /// una ventana aparte.
    private func openNote(_ note: Note, sticky: Bool) {
        let id = note.persistentModelID
        if deck.openID == id {
            if sticky, !deck.stickyOpen { fixOpen(); return }   // el hover la abrió, el click la fija
            if sticky { closeNote() }
            return
        }

        exitWork?.cancel(); shrinkWork?.cancel()
        if !deck.fanned {
            fannedFrameNow()
            deck.fanned = true
            deck.revealTick &+= 1
        }
        deck.openedTop = nil
        deck.stickyOpen = sticky
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { deck.openID = id }
        // el sondeo corre siempre que el deck esté abierto; el tick se saltea solo
        // mientras la nota está fijada, así al cerrarla con Esc vuelve el auto-cierre
        startWatch()
        if sticky { fixOpen() }
    }

    /// Fija la nota abierta y le da el teclado. `.nonactivatingPanel` no activa la
    /// app: sin el activate, makeKey no basta para que el teclado llegue al editor.
    private func fixOpen() {
        deck.stickyOpen = true
        NSApp.activate(ignoringOtherApps: true)
        stripPanel?.makeKeyAndOrderFront(nil)
    }

    private func closeNote() {
        guard deck.openID != nil else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) { deck.openID = nil }
        deck.openedTop = nil
        deck.stickyOpen = false
    }

    private func deleteWithUndo(note: Note, id: PersistentIdentifier) {
        let context = AppContainer.shared.mainContext

        let snapshot = Note()
        snapshot.title = note.title
        snapshot.body = note.body
        snapshot.tags = note.tags
        snapshot.pinned = note.pinned
        snapshot.colorHex = note.colorHex

        closeNote()
        context.delete(note)
        try? context.save()

        showUndoToast {
            context.insert(snapshot)
            try? context.save()
        }
    }

    private var undoToastPanel: NSPanel?
    private var undoDismissWorkItem: DispatchWorkItem?

    private func showUndoToast(onUndo: @escaping () -> Void) {
        undoDismissWorkItem?.cancel()
        undoToastPanel?.orderOut(nil)

        guard let screen = NSScreen.main else { return }

        let view = UndoToastView { [weak self] in
            onUndo()
            self?.undoToastPanel?.orderOut(nil)
            self?.undoToastPanel = nil
        }
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 220, height: 44)

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hosting
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let x = screen.visibleFrame.midX - hosting.frame.width / 2
        let y = screen.visibleFrame.minY + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }

        undoToastPanel = panel

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.undoToastPanel === panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
            self.undoToastPanel = nil
        }
        undoDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

}
#endif

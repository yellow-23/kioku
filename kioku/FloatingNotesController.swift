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

final class FloatingNotesController: NSObject {
    static let shared = FloatingNotesController()

    private var stripPanel: NSPanel?
    private var stickyWindows: [PersistentIdentifier: NSPanel] = [:]

    var isVisible: Bool { stripPanel != nil }

    func hideStrip() {
        for (_, panel) in stickyWindows { panel.orderOut(nil) }
        stickyWindows.removeAll()
        stripPanel?.orderOut(nil)
        stripPanel = nil
    }

    func showStrip() {
        guard stripPanel == nil, let screen = NSScreen.main else { return }

        let stripSize = NSSize(width: 60, height: 320)
        let strip = TabStripView { [weak self] note in
            self?.toggleSticky(for: note)
        }
        .frame(width: stripSize.width, height: stripSize.height, alignment: .leading)

        let hosting = FirstMouseHostingView(rootView: strip.modelContainer(AppContainer.shared))
        hosting.frame = NSRect(origin: .zero, size: stripSize)
        // sin esto, NSHostingView reajusta la ventana al tamaño intrínseco del contenido
        // (p.ej. al quedar sin notas) y corta la animación de deslizamiento a mitad de camino
        hosting.sizingOptions = []

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hosting
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.alphaValue = 0

        let finalX = screen.visibleFrame.maxX - hosting.frame.width
        let y = screen.visibleFrame.midY - hosting.frame.height / 2
        let finalFrame = NSRect(x: finalX, y: y, width: hosting.frame.width, height: hosting.frame.height)

        // arranca fuera de pantalla y se desliza hacia adentro
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX + 30, y: y))
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            // setFrameOrigin no es animatable en NSWindow; setFrame(_:display:) sí lo es
            panel.animator().setFrame(finalFrame, display: true)
        }

        stripPanel = panel
    }

    private func toggleSticky(for note: Note) {
        let id = note.persistentModelID

        if let existing = stickyWindows[id] {
            animateOut(existing) { [weak self] in
                self?.stickyWindows[id] = nil
            }
            return
        }

        let view = StickyNoteView(
            note: note,
            onClose: { [weak self] in self?.closeSticky(id: id) },
            onDelete: { [weak self] in self?.deleteWithUndo(note: note, id: id) }
        )
        .frame(width: 280, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 14))

        let hosting = FirstMouseHostingView(rootView: view)
        let targetSize = NSSize(width: 280, height: 260)
        hosting.frame = NSRect(origin: .zero, size: targetSize)
        hosting.sizingOptions = []

        let panel = KeyablePanel(
            contentRect: hosting.frame,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.contentView = hosting
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        var targetOrigin = NSPoint(x: 200, y: 200)
        var startOrigin = targetOrigin

        if let screen = NSScreen.main, let strip = stripPanel {
            let x = strip.frame.minX - targetSize.width - 8
            let y = min(strip.frame.midY - targetSize.height / 2, screen.visibleFrame.maxY - targetSize.height)
            targetOrigin = NSPoint(x: x, y: y)
            // arranca colapsada, saliendo desde la franja de pestañas
            startOrigin = NSPoint(x: strip.frame.minX - 20, y: strip.frame.midY - 20)
        }

        panel.setFrame(NSRect(origin: startOrigin, size: NSSize(width: 40, height: 40)), display: false)
        panel.alphaValue = 0
        // .nonactivatingPanel no activa la app: sin esto, makeKeyAndOrderFront no basta
        // para que el teclado llegue al TextField/TextEditor de adentro
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(NSRect(origin: targetOrigin, size: targetSize), display: true)
        }

        stickyWindows[id] = panel
    }

    private func deleteWithUndo(note: Note, id: PersistentIdentifier) {
        let context = AppContainer.shared.mainContext

        let snapshot = Note()
        snapshot.title = note.title
        snapshot.body = note.body
        snapshot.tags = note.tags
        snapshot.pinned = note.pinned
        snapshot.colorHex = note.colorHex

        closeSticky(id: id)
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

    private func closeSticky(id: PersistentIdentifier) {
        guard let panel = stickyWindows[id] else { return }
        animateOut(panel) { [weak self] in
            self?.stickyWindows[id] = nil
        }
    }

    private func animateOut(_ panel: NSPanel, completion: @escaping () -> Void) {
        let collapsed = NSRect(
            x: panel.frame.midX - 20,
            y: panel.frame.midY - 20,
            width: 40,
            height: 40
        )
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(collapsed, display: true)
        }, completionHandler: {
            panel.orderOut(nil)
            completion()
        })
    }
}
#endif

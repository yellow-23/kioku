import SwiftUI
import SwiftData

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FloatingNotesController.shared.showStrip()
        setupStatusItem()
        // la ventana de WindowGroup se crea un instante después de este callback
        DispatchQueue.main.async { [weak self] in
            self?.hideMainWindow()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Kioku")
        item.button?.action = #selector(toggleView)
        item.button?.target = self
        statusItem = item
    }

    @objc private func toggleView() {
        if FloatingNotesController.shared.isVisible {
            FloatingNotesController.shared.hideStrip()
            showMainWindow()
        } else {
            hideMainWindow()
            FloatingNotesController.shared.showStrip()
        }
    }

    private func mainWindow() -> NSWindow? {
        NSApp.windows.first { !($0 is NSPanel) }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow()?.makeKeyAndOrderFront(nil)
    }

    private func hideMainWindow() {
        mainWindow()?.orderOut(nil)
    }
}
#endif

@main
struct kiokuApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(AppContainer.shared)
    }
}

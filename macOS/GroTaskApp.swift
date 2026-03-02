import SwiftUI

@main
struct GroTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private let store: TaskStore

    override init() {
        self.store = TaskStore(context: PersistenceController.shared.container.viewContext)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        positionNearStatusItem()
        panel.makeKeyAndOrderFront(nil)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "checklist",
                accessibilityDescription: "GroTask"
            )
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPanel() {
        panel = FloatingPanel {
            TaskPopoverView(store: self.store)
        }
    }

    @objc private func togglePanel() {
        panel.makeKeyAndOrderFront(nil)
    }

    private func positionNearStatusItem() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let buttonRect = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        let x = buttonRect.midX - panelWidth / 2
        let y = buttonRect.minY - panelHeight - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

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
        // 触发迁移
        MigrationHelper.migrateIfNeeded(context: PersistenceController.shared.container.viewContext)
        self.store = TaskStore()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
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
        store.refreshFromStore()
        panel.makeKeyAndOrderFront(nil)
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        // CloudKit import and UI refresh are driven by NSPersistentCloudKitContainer events.
    }

    private func positionNearStatusItem() {
        guard let screen = NSScreen.main else { return }

        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        let visibleFrame = screen.visibleFrame

        // 屏幕右上角，留 8pt 边距
        let x = visibleFrame.maxX - panelWidth - 8
        let y = visibleFrame.maxY - panelHeight - 8

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

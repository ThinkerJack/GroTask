import SwiftUI
import UIKit

@main
struct GroTaskiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegateiOS.self) var appDelegate
    let store: TaskStore

    init() {
        MigrationHelper.migrateIfNeeded(context: PersistenceController.shared.container.viewContext)
        self.store = TaskStore()
    }

    var body: some Scene {
        WindowGroup {
            TaskListView(store: store)
        }
    }
}

final class AppDelegateiOS: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
}

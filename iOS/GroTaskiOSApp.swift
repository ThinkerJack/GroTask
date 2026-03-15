import SwiftUI
import UIKit

@main
struct GroTaskiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegateiOS.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    let store: TaskStore

    init() {
        MigrationHelper.migrateIfNeeded(context: PersistenceController.shared.container.viewContext)
        self.store = TaskStore()
    }

    var body: some Scene {
        WindowGroup {
            TaskListView(store: store)
                .onAppear {
                    store.refreshFromStore()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.refreshFromStore()
                    }
                }
        }
    }
}

final class AppDelegateiOS: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
}

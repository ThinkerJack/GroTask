import SwiftUI
import UIKit
import os.log

private let syncLog = Logger(subsystem: "com.grotask.app", category: "CloudKitSync")

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

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        syncLog.info("推送注册成功, token 长度: \(deviceToken.count)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        syncLog.error("推送注册失败: \(error.localizedDescription, privacy: .public)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        syncLog.info("收到远程推送通知")
        completionHandler(.newData)
    }
}

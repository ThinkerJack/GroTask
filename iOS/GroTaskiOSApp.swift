import SwiftUI

@main
struct GroTaskiOSApp: App {
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

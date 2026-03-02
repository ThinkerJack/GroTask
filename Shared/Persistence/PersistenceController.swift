import CoreData

struct PersistenceController {
    let container: NSPersistentContainer

    /// 生产环境使用 CloudKit 容器
    static let shared = PersistenceController()

    init(inMemory: Bool = false) {
        if inMemory {
            container = NSPersistentContainer(name: "GroTask")
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            container = NSPersistentCloudKitContainer(name: "GroTask")
            container.persistentStoreDescriptions.first?.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.grotask.app")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

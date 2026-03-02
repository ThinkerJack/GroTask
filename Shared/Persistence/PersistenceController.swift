import CoreData

struct PersistenceController {
    let container: NSPersistentContainer

    /// 生产环境使用 CloudKit 容器
    /// CloudKit 同步需要配置签名后启用: PersistenceController(cloudKit: true)
    static let shared = PersistenceController()

    init(inMemory: Bool = false, cloudKit: Bool = false) {
        if inMemory {
            container = NSPersistentContainer(name: "GroTask")
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else if cloudKit {
            container = NSPersistentCloudKitContainer(name: "GroTask")
            container.persistentStoreDescriptions.first?.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.grotask.app")
        } else {
            container = NSPersistentContainer(name: "GroTask")
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

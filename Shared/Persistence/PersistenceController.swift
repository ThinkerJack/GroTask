import CoreData

struct PersistenceController {
    let container: NSPersistentContainer

    static let shared = PersistenceController(cloudKit: true)

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

        // 在 debug 模式下异步初始化 CloudKit schema，避免阻塞启动
        #if DEBUG
        if cloudKit, let cloudKitContainer = container as? NSPersistentCloudKitContainer {
            DispatchQueue.global(qos: .utility).async {
                try? cloudKitContainer.initializeCloudKitSchema(options: [])
            }
        }
        #endif
    }
}

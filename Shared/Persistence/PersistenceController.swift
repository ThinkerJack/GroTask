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
            let description = container.persistentStoreDescriptions.first!
            description.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.grotask.app")
            // CloudKit 同步必需：开启持久化历史追踪
            description.setOption(true as NSNumber,
                forKey: NSPersistentHistoryTrackingKey)
            // 远端变更到达时发出通知
            description.setOption(true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
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
        container.viewContext.stalenessInterval = 0

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

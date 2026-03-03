import Foundation
import CoreData

enum MigrationHelper {

    /// 检查旧 JSON 文件是否存在，如果存在则迁移到 Core Data。
    /// 返回 true 表示执行了迁移。
    @discardableResult
    static func migrateIfNeeded(jsonDirectory: URL? = nil, context: NSManagedObjectContext) -> Bool {
        let dir = jsonDirectory ?? defaultJSONDirectory()
        let jsonURL = dir.appendingPathComponent("tasks.json")
        let migratedURL = dir.appendingPathComponent("tasks.json.migrated")

        // 如果已迁移或没有旧文件，跳过
        guard FileManager.default.fileExists(atPath: jsonURL.path),
              !FileManager.default.fileExists(atPath: migratedURL.path) else {
            return false
        }

        // 读取旧 JSON
        guard let data = try? Data(contentsOf: jsonURL) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let tasks = try? decoder.decode([TaskItem].self, from: data) else { return false }

        // 写入 Core Data
        for task in tasks {
            let entity = TaskItemEntity(context: context)
            entity.id = task.id
            entity.title = task.title
            entity.statusRaw = Int16(task.status.rawValue)
            entity.categoryRaw = task.category == .work ? 0 : 1
            entity.isPinned = task.isPinned
            entity.createdAt = task.createdAt
            entity.completedAt = task.completedAt
            entity.timeScopeRaw = Int16(task.timeScope.rawValue)
        }

        do {
            try context.save()
            // 重命名旧文件
            try FileManager.default.moveItem(at: jsonURL, to: migratedURL)
            return true
        } catch {
            print("Migration failed: \(error)")
            return false
        }
    }

    private static func defaultJSONDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("GroTask", isDirectory: true)
    }
}

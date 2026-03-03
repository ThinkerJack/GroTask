import CoreData

@objc(TaskItemEntity)
public class TaskItemEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var statusRaw: Int16
    @NSManaged public var categoryRaw: Int16
    @NSManaged public var isPinned: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var completedAt: Date?
}

extension TaskItemEntity {
    var status: TaskStatus {
        get { TaskStatus(rawValue: Int(statusRaw)) ?? .todo }
        set { statusRaw = Int16(newValue.rawValue) }
    }

    var category: TaskCategory {
        get { TaskCategory.allCases.first { $0.rawValue == (categoryRaw == 0 ? "work" : "life") } ?? .work }
        set { categoryRaw = newValue == .work ? 0 : 1 }
    }

    func toTaskItem() -> TaskItem {
        TaskItem(
            id: id ?? UUID(),
            title: title ?? "",
            status: status,
            category: category,
            isPinned: isPinned,
            timeScope: .anytime,
            createdAt: createdAt ?? Date(),
            completedAt: completedAt
        )
    }
}

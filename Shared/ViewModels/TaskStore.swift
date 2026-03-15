import Foundation
import CoreData
import SwiftUI

@Observable
final class TaskStore {

    private(set) var tasks: [TaskItem] = []
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?

    private let context: NSManagedObjectContext

    convenience init() {
        let persistence = PersistenceController.shared
        self.init(context: persistence.container.viewContext, container: persistence.container)
    }

    convenience init(context: NSManagedObjectContext) {
        self.init(context: context, container: NSPersistentContainer(name: "GroTask"))
    }

    private init(context: NSManagedObjectContext, container: NSPersistentContainer) {
        self.context = context
        fetchAll()

        NotificationCenter.default.addObserver(
            self, selector: #selector(contextDidChange),
            name: .NSManagedObjectContextObjectsDidChange, object: context
        )

        if let cloudKitContainer = container as? NSPersistentCloudKitContainer {
            NotificationCenter.default.addObserver(
                self, selector: #selector(cloudKitEventChanged),
                name: NSPersistentCloudKitContainer.eventChangedNotification,
                object: cloudKitContainer
            )
        }
    }

    @objc private func contextDidChange(_ notification: Notification) {
        if Thread.isMainThread {
            fetchAll()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.fetchAll()
            }
        }
    }

    @objc private func cloudKitEventChanged(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        guard event.type == .import else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if event.endDate == nil {
                self.isSyncing = true
                return
            }

            self.isSyncing = false
            if let error = event.error {
                self.syncError = error
                print("CloudKit import failed: \(error)")
                return
            }

            self.syncError = nil
            self.lastSyncDate = Date()
            self.context.refreshAllObjects()
            self.fetchAll()
        }
    }

    /// 丢弃 viewContext 缓存并重新从本地 store 读取。
    func refreshFromStore() {
        context.refreshAllObjects()
        fetchAll()
    }

    // MARK: - Fetch

    private func fetchAll() {
        let request = NSFetchRequest<TaskItemEntity>(entityName: "TaskItemEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskItemEntity.createdAt, ascending: false)]
        do {
            let entities = try context.fetch(request)
            tasks = entities.map { $0.toTaskItem() }
        } catch {
            print("TaskStore fetch failed: \(error)")
            tasks = []
        }
    }

    // MARK: - CRUD

    func addTask(title: String, category: TaskCategory = .work, timeScope: TaskTimeScope = .anytime) {
        let entity = TaskItemEntity(context: context)
        entity.id = UUID()
        entity.title = title
        entity.statusRaw = Int16(TaskStatus.todo.rawValue)
        entity.categoryRaw = category == .work ? 0 : 1
        entity.isPinned = false
        entity.createdAt = Date()
        entity.completedAt = nil
        entity.timeScopeRaw = Int16(timeScope.rawValue)
        save()
    }

    func deleteTask(id: UUID) {
        guard let entity = findEntity(id: id) else { return }
        context.delete(entity)
        save()
    }

    func cycleStatus(id: UUID) {
        guard let entity = findEntity(id: id) else { return }
        let currentStatus = entity.status
        entity.status = currentStatus.next
        if entity.status == .done {
            entity.completedAt = Date()
        } else {
            entity.completedAt = nil
        }
        save()
    }

    func togglePin(id: UUID) {
        guard let entity = findEntity(id: id) else { return }
        entity.isPinned.toggle()
        save()
    }

    func toggleCategory(id: UUID) {
        guard let entity = findEntity(id: id) else { return }
        entity.category = entity.category.next
        save()
    }

    func setTimeScope(id: UUID, scope: TaskTimeScope) {
        guard let entity = findEntity(id: id) else { return }
        entity.timeScope = scope
        save()
    }

    func updateTitle(id: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let entity = findEntity(id: id) else { return }
        entity.title = trimmed
        save()
    }

    // MARK: - Grouped Queries

    var pinnedTasks: [TaskItem] {
        tasks
            .filter { $0.isPinned && $0.status == .todo }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var unpinnedTasks: [TaskItem] {
        tasks
            .filter { !$0.isPinned && $0.status == .todo }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var doneTasks: [TaskItem] {
        tasks
            .filter { $0.status == .done }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func tasks(for scope: TaskTimeScope) -> [TaskItem] {
        tasks
            .filter { $0.timeScope == scope && $0.status == .todo && !$0.isPinned }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func tasks(for status: TaskStatus) -> [TaskItem] {
        let filtered = tasks.filter { $0.status == status }
        if status == .done {
            return filtered.sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
        }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Private

    private func findEntity(id: UUID) -> TaskItemEntity? {
        let request = NSFetchRequest<TaskItemEntity>(entityName: "TaskItemEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            fetchAll()
        } catch {
            print("TaskStore save failed: \(error)")
        }
    }
}

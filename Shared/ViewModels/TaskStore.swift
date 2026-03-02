import Foundation
import CoreData
import SwiftUI

@Observable
final class TaskStore {

    private(set) var tasks: [TaskItem] = []
    private let context: NSManagedObjectContext

    convenience init() {
        self.init(context: PersistenceController.shared.container.viewContext)
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        fetchAll()

        // 监听远端同步变更
        NotificationCenter.default.addObserver(
            self, selector: #selector(contextDidChange),
            name: .NSManagedObjectContextObjectsDidChange, object: context
        )
    }

    @objc private func contextDidChange(_ notification: Notification) {
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

    func addTask(title: String, category: TaskCategory = .work) {
        let entity = TaskItemEntity(context: context)
        entity.id = UUID()
        entity.title = title
        entity.statusRaw = Int16(TaskStatus.todo.rawValue)
        entity.categoryRaw = category == .work ? 0 : 1
        entity.isPinned = false
        entity.createdAt = Date()
        entity.completedAt = nil
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

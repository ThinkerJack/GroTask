import Foundation
import CoreData
import os.log
import SwiftUI

private let syncLog = Logger(subsystem: "com.grotask.app", category: "CloudKitSync")

@Observable
final class TaskStore {

    private(set) var tasks: [TaskItem] = []
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?

    private let context: NSManagedObjectContext
    private var observerTokens: [NSObjectProtocol] = []
    private var pendingRemoteRefreshWorkItem: DispatchWorkItem?

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

        let center = NotificationCenter.default
        observerTokens.append(
            center.addObserver(
                forName: .NSManagedObjectContextObjectsDidChange,
                object: context,
                queue: nil
            ) { [weak self] _ in
                self?.scheduleFetchAll()
            }
        )

        if let cloudKitContainer = container as? NSPersistentCloudKitContainer {
            syncLog.info("注册 CloudKit 事件通知")
            observerTokens.append(
                center.addObserver(
                    forName: NSPersistentCloudKitContainer.eventChangedNotification,
                    object: nil,
                    queue: nil
                ) { [weak self] notification in
                    self?.handleCloudKitEventChanged(notification)
                }
            )

            observerTokens.append(
                center.addObserver(
                    forName: .NSPersistentStoreRemoteChange,
                    object: cloudKitContainer.persistentStoreCoordinator,
                    queue: nil
                ) { [weak self] _ in
                    self?.scheduleRemoteRefreshFallback()
                }
            )
        } else {
            syncLog.warning("容器不是 NSPersistentCloudKitContainer，CloudKit 同步不可用")
        }
    }

    deinit {
        pendingRemoteRefreshWorkItem?.cancel()
        let center = NotificationCenter.default
        for token in observerTokens {
            center.removeObserver(token)
        }
    }

    private func handleCloudKitEventChanged(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        let typeName: String
        switch event.type {
        case .setup:  typeName = "setup"
        case .import: typeName = "import"
        case .export: typeName = "export"
        @unknown default: typeName = "unknown"
        }

        if let endDate = event.endDate {
            let duration = endDate.timeIntervalSince(event.startDate)
            if let error = event.error {
                syncLog.error("CloudKit \(typeName, privacy: .public) 失败 (耗时 \(duration, format: .fixed(precision: 1))s): \(error.localizedDescription, privacy: .public)")
            } else {
                syncLog.info("CloudKit \(typeName, privacy: .public) 完成 (耗时 \(duration, format: .fixed(precision: 1))s)")
            }
        } else {
            syncLog.info("CloudKit \(typeName, privacy: .public) 开始...")
        }

        // setup 失败时记录到 syncError，方便排查
        if event.type == .setup, event.endDate != nil, let error = event.error {
            DispatchQueue.main.async { [weak self] in
                self?.syncError = error
            }
            return
        }

        guard event.type == .import else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if event.endDate == nil {
                self.isSyncing = true
                return
            }

            self.pendingRemoteRefreshWorkItem?.cancel()
            self.isSyncing = false
            if let error = event.error {
                self.syncError = error
                return
            }

            self.syncError = nil
            self.lastSyncDate = event.endDate ?? Date()
            self.refreshFromStore()
        }
    }

    private func scheduleFetchAll() {
        if Thread.isMainThread {
            fetchAll()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.fetchAll()
            }
        }
    }

    private func scheduleRemoteRefreshFallback() {
        pendingRemoteRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            syncLog.info("远端变更 fallback 刷新")
            self.refreshFromStore()
        }
        pendingRemoteRefreshWorkItem = workItem
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
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

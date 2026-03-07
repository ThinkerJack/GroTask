import CloudKit
import CoreData

/// 定期从 CloudKit 拉取变更，绕过不可靠的静默推送
final class CloudKitPoller {
    private let container: CKContainer
    private let database: CKDatabase
    private let context: NSManagedObjectContext
    private var timer: Timer?
    private let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
    private var changeToken: CKServerChangeToken?

    init(context: NSManagedObjectContext, containerIdentifier: String = "iCloud.com.grotask.app") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = self.container.privateCloudDatabase
        self.context = context
    }

    func startPolling(interval: TimeInterval = 10) {
        fetchChanges()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchChanges()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// 手动触发一次拉取
    func fetchChanges() {
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = changeToken

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: config])

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        operation.recordWasChangedBlock = { _, result in
            if case .success(let record) = result {
                changedRecords.append(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { [weak self] _, token, _ in
            self?.changeToken = token
        }

        operation.recordZoneFetchResultBlock = { [weak self] _, result in
            if case .success(let (token, _, _)) = result {
                self?.changeToken = token
            }
            guard let self else { return }
            if !changedRecords.isEmpty || !deletedRecordIDs.isEmpty {
                self.applyChanges(changed: changedRecords, deleted: deletedRecordIDs)
            }
        }

        operation.qualityOfService = .userInitiated
        database.add(operation)
    }

    // MARK: - 将 CloudKit 记录合并到 Core Data

    private func applyChanges(changed: [CKRecord], deleted: [CKRecord.ID]) {
        context.perform { [weak self] in
            guard let self else { return }

            for record in changed {
                guard record.recordType == "CD_TaskItemEntity" else { continue }
                guard let idString = record["CD_id"] as? String,
                      let uuid = UUID(uuidString: idString) else { continue }

                let entity = self.findOrCreate(id: uuid)
                entity.title = record["CD_title"] as? String
                entity.statusRaw = (record["CD_statusRaw"] as? Int64).map { Int16($0) } ?? 0
                entity.categoryRaw = (record["CD_categoryRaw"] as? Int64).map { Int16($0) } ?? 0
                entity.isPinned = (record["CD_isPinned"] as? Int64).map { $0 != 0 } ?? false
                entity.timeScopeRaw = (record["CD_timeScopeRaw"] as? Int64).map { Int16($0) } ?? 2
                entity.createdAt = record["CD_createdAt"] as? Date
                entity.completedAt = record["CD_completedAt"] as? Date
            }

            for recordID in deleted {
                // CD_ record name 格式通常是 UUID
                let name = recordID.recordName
                if let uuid = UUID(uuidString: name),
                   let entity = self.findEntity(id: uuid) {
                    self.context.delete(entity)
                }
            }

            if self.context.hasChanges {
                try? self.context.save()
            }
        }
    }

    private func findOrCreate(id: UUID) -> TaskItemEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = TaskItemEntity(context: context)
        entity.id = id
        return entity
    }

    private func findEntity(id: UUID) -> TaskItemEntity? {
        let request = NSFetchRequest<TaskItemEntity>(entityName: "TaskItemEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

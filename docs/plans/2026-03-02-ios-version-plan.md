# GroTask iOS 版本实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 GroTask 添加 iOS target，通过 Core Data + NSPersistentCloudKitContainer 实现 macOS/iOS 任务同步。

**Architecture:** 同仓库多 Target 结构。将现有代码拆分为 Shared（模型/持久化/ViewModel）、macOS（AppKit views）、iOS（SwiftUI views）三个目录。持久化层从 JSON 文件迁移到 Core Data + CloudKit。

**Tech Stack:** SwiftUI, Core Data, CloudKit (NSPersistentCloudKitContainer), XcodeGen

---

### Task 1: 重组目录结构

**Files:**
- Move: `GroTask/Models/TaskItem.swift` → `Shared/Models/TaskItem.swift`
- Move: `GroTask/ViewModels/TaskStore.swift` → `Shared/ViewModels/TaskStore.swift`
- Move: `GroTask/GroTaskApp.swift` → `macOS/GroTaskApp.swift`
- Move: `GroTask/Views/FloatingPanel.swift` → `macOS/Views/FloatingPanel.swift`
- Move: `GroTask/Views/TaskPopoverView.swift` → `macOS/Views/TaskPopoverView.swift`
- Move: `GroTask/Views/TaskRowView.swift` → `macOS/Views/TaskRowView.swift`
- Move: `GroTask/GroTask.entitlements` → `macOS/GroTask.entitlements`
- Move: `GroTask/Info.plist` → `macOS/Info.plist`
- Move: `GroTask/Assets.xcassets` → `Shared/Assets.xcassets`

**Step 1: 创建目录并移动文件**

```bash
mkdir -p Shared/Models Shared/ViewModels Shared/Persistence macOS/Views iOS/Views

# 共享代码
mv GroTask/Models/TaskItem.swift Shared/Models/TaskItem.swift
mv GroTask/ViewModels/TaskStore.swift Shared/ViewModels/TaskStore.swift
mv GroTask/Assets.xcassets Shared/Assets.xcassets

# macOS 专属
mv GroTask/GroTaskApp.swift macOS/GroTaskApp.swift
mv GroTask/Views/FloatingPanel.swift macOS/Views/FloatingPanel.swift
mv GroTask/Views/TaskPopoverView.swift macOS/Views/TaskPopoverView.swift
mv GroTask/Views/TaskRowView.swift macOS/Views/TaskRowView.swift
mv GroTask/GroTask.entitlements macOS/GroTask.entitlements
mv GroTask/Info.plist macOS/Info.plist
```

**Step 2: 更新 project.yml 的 source 路径**

修改 `project.yml`，将 GroTask target 的 sources 从 `GroTask` 改为 `[Shared/, macOS/]`：

```yaml
name: GroTask
options:
  bundleIdPrefix: com.grotask
  deploymentTarget:
    macOS: "15.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "15.0"

targets:
  GroTask:
    type: application
    platform: macOS
    sources:
      - path: Shared
      - path: macOS
    settings:
      base:
        INFOPLIST_FILE: macOS/Info.plist
        CODE_SIGN_ENTITLEMENTS: macOS/GroTask.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.grotask.app
        PRODUCT_NAME: GroTask
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        COMBINE_HIDPI_IMAGES: true
    info:
      path: macOS/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: GroTask
        CFBundleDisplayName: GroTask
        CFBundleIdentifier: com.grotask.app
        CFBundleVersion: "1"
        CFBundleShortVersionString: "1.0.0"
        CFBundlePackageType: APPL
        CFBundleExecutable: GroTask
        LSMinimumSystemVersion: "15.0"
        NSHighResolutionCapable: true

  GroTaskTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: GroTaskTests
    dependencies:
      - target: GroTask
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.grotask.tests
        GENERATE_INFOPLIST_FILE: "YES"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/GroTask.app/Contents/MacOS/GroTask"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

**Step 3: 重新生成 Xcode 项目并验证编译**

```bash
xcodegen generate
xcodebuild -scheme GroTask -destination 'platform=macOS' build
```

Expected: 编译成功，所有现有功能不受影响。

**Step 4: 运行测试确认没有回归**

```bash
xcodebuild test -scheme GroTask -destination 'platform=macOS'
```

Expected: 全部 31 个测试通过。

**Step 5: 提交**

```bash
git add -A
git commit -m "refactor: reorganize project into Shared/macOS/iOS directory structure"
```

---

### Task 2: 创建 Core Data 模型

**Files:**
- Create: `Shared/Persistence/GroTask.xcdatamodeld/GroTask.xcdatamodel/contents`

**Step 1: 创建 Core Data 模型文件**

创建 `Shared/Persistence/GroTask.xcdatamodeld/GroTask.xcdatamodel/contents`：

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0"
       lastSavedToolsVersion="23231" systemVersion="24D81"
       minimumToolsVersion="Automatic" sourceLanguage="Swift"
       usedWithCloudKit="YES" usedWithSwiftData="NO">
    <entity name="TaskItemEntity" representedClassName="TaskItemEntity" syncable="YES">
        <attribute name="id" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="title" attributeType="String" defaultValueString=""/>
        <attribute name="statusRaw" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="categoryRaw" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="isPinned" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
        <attribute name="createdAt" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="completedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    </entity>
</model>
```

**Step 2: 创建 NSManagedObject 子类**

创建 `Shared/Persistence/TaskItemEntity.swift`：

```swift
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
            createdAt: createdAt ?? Date(),
            completedAt: completedAt
        )
    }
}
```

**Step 3: 更新 TaskItem 添加完整初始化器**

在 `Shared/Models/TaskItem.swift` 添加内部初始化器（用于从 Core Data 转换）：

```swift
// 在 TaskItem struct 中添加，现有 init 保持不变
init(id: UUID, title: String, status: TaskStatus, category: TaskCategory,
     isPinned: Bool, createdAt: Date, completedAt: Date?) {
    self.id = id
    self.title = title
    self.status = status
    self.category = category
    self.isPinned = isPinned
    self.createdAt = createdAt
    self.completedAt = completedAt
}
```

**Step 4: 编译验证**

```bash
xcodegen generate
xcodebuild -scheme GroTask -destination 'platform=macOS' build
```

Expected: 编译成功。

**Step 5: 提交**

```bash
git add -A
git commit -m "feat: add Core Data model for TaskItemEntity"
```

---

### Task 3: 创建 PersistenceController

**Files:**
- Create: `Shared/Persistence/PersistenceController.swift`
- Test: `GroTaskTests/PersistenceControllerTests.swift`

**Step 1: 写失败的测试**

创建 `GroTaskTests/PersistenceControllerTests.swift`：

```swift
import XCTest
import CoreData
@testable import GroTask

final class PersistenceControllerTests: XCTestCase {

    func testInMemoryControllerCreatesContext() {
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.container.viewContext)
    }

    func testInMemoryControllerCanSaveAndFetch() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let entity = TaskItemEntity(context: context)
        entity.id = UUID()
        entity.title = "Test task"
        entity.statusRaw = 0
        entity.categoryRaw = 0
        entity.isPinned = false
        entity.createdAt = Date()

        try context.save()

        let request = NSFetchRequest<TaskItemEntity>(entityName: "TaskItemEntity")
        let results = try context.fetch(request)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Test task")
    }
}
```

**Step 2: 运行测试确认失败**

```bash
xcodebuild test -scheme GroTask -destination 'platform=macOS'
```

Expected: FAIL — `PersistenceController` 未定义。

**Step 3: 实现 PersistenceController**

创建 `Shared/Persistence/PersistenceController.swift`：

```swift
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
```

**Step 4: 运行测试确认通过**

```bash
xcodebuild test -scheme GroTask -destination 'platform=macOS'
```

Expected: 全部通过。

**Step 5: 提交**

```bash
git add -A
git commit -m "feat: add PersistenceController with CloudKit support"
```

---

### Task 4: 重写 TaskStore 使用 Core Data

**Files:**
- Modify: `Shared/ViewModels/TaskStore.swift`
- Modify: `GroTaskTests/TaskStoreTests.swift`

**Step 1: 重写 TaskStore**

将 `Shared/ViewModels/TaskStore.swift` 替换为：

```swift
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
```

**Step 2: 重写 TaskStoreTests 使用 in-memory Core Data**

将 `GroTaskTests/TaskStoreTests.swift` 替换为：

```swift
import XCTest
import CoreData
@testable import GroTask

final class TaskStoreTests: XCTestCase {

    var store: TaskStore!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        store = TaskStore(context: context)
    }

    override func tearDown() {
        store = nil
        context = nil
        super.tearDown()
    }

    func testAddTask() {
        XCTAssertEqual(store.tasks.count, 0)
        store.addTask(title: "Buy groceries", category: .life)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].title, "Buy groceries")
        XCTAssertEqual(store.tasks[0].status, .todo)
        XCTAssertEqual(store.tasks[0].category, .life)
        XCTAssertFalse(store.tasks[0].isPinned)
    }

    func testAddTaskDefaultCategory() {
        store.addTask(title: "Code review")
        XCTAssertEqual(store.tasks[0].category, .work)
    }

    func testDeleteTask() {
        store.addTask(title: "Task to delete")
        let id = store.tasks[0].id
        store.deleteTask(id: id)
        XCTAssertEqual(store.tasks.count, 0)
    }

    func testCycleTaskStatus() {
        store.addTask(title: "Cycle me")
        let id = store.tasks[0].id

        store.cycleStatus(id: id)
        XCTAssertEqual(store.tasks[0].status, .done)
        XCTAssertNotNil(store.tasks[0].completedAt)

        store.cycleStatus(id: id)
        XCTAssertEqual(store.tasks[0].status, .todo)
        XCTAssertNil(store.tasks[0].completedAt)
    }

    func testTogglePin() {
        store.addTask(title: "Pin me")
        let id = store.tasks[0].id
        XCTAssertFalse(store.tasks[0].isPinned)

        store.togglePin(id: id)
        XCTAssertTrue(store.tasks[0].isPinned)

        store.togglePin(id: id)
        XCTAssertFalse(store.tasks[0].isPinned)
    }

    func testToggleCategory() {
        store.addTask(title: "Switch category")
        let id = store.tasks[0].id
        XCTAssertEqual(store.tasks[0].category, .work)

        store.toggleCategory(id: id)
        XCTAssertEqual(store.tasks[0].category, .life)

        store.toggleCategory(id: id)
        XCTAssertEqual(store.tasks[0].category, .work)
    }

    func testPinnedTasks() {
        store.addTask(title: "Normal task")
        store.addTask(title: "Pinned task")
        store.togglePin(id: store.tasks[0].id)

        XCTAssertEqual(store.pinnedTasks.count, 1)
        XCTAssertEqual(store.pinnedTasks[0].title, "Pinned task")
    }

    func testUnpinnedTasks() {
        store.addTask(title: "Normal task")
        store.addTask(title: "Pinned task")
        store.togglePin(id: store.tasks[0].id)

        XCTAssertEqual(store.unpinnedTasks.count, 1)
        XCTAssertEqual(store.unpinnedTasks[0].title, "Normal task")
    }

    func testDoneTasks() {
        store.addTask(title: "Done task")
        store.addTask(title: "Todo task")
        store.cycleStatus(id: store.tasks[1].id)

        XCTAssertEqual(store.doneTasks.count, 1)
        XCTAssertEqual(store.doneTasks[0].title, "Done task")
    }

    func testPinnedDoneTaskNotInPinned() {
        store.addTask(title: "Was pinned")
        let id = store.tasks[0].id
        store.togglePin(id: id)
        store.cycleStatus(id: id)

        XCTAssertEqual(store.pinnedTasks.count, 0)
        XCTAssertEqual(store.doneTasks.count, 1)
    }
}
```

**Step 3: 运行测试**

```bash
xcodegen generate
xcodebuild test -scheme GroTask -destination 'platform=macOS'
```

Expected: 全部通过。注意：移除了 `testPersistenceRoundTrip` 和 `testCorruptFileRecovery`（JSON 专属逻辑已不适用）。

**Step 4: 提交**

```bash
git add -A
git commit -m "feat: rewrite TaskStore to use Core Data persistence"
```

---

### Task 5: JSON → Core Data 数据迁移

**Files:**
- Create: `Shared/Persistence/MigrationHelper.swift`
- Test: `GroTaskTests/MigrationHelperTests.swift`

**Step 1: 写失败的测试**

创建 `GroTaskTests/MigrationHelperTests.swift`：

```swift
import XCTest
import CoreData
@testable import GroTask

final class MigrationHelperTests: XCTestCase {

    var context: NSManagedObjectContext!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        let controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testMigrateFromJSON() throws {
        // Create a JSON file with tasks
        let tasks = [
            TaskItem(title: "Task 1", category: .work),
            TaskItem(title: "Task 2", category: .life)
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(tasks)
        let jsonURL = tempDir.appendingPathComponent("tasks.json")
        try data.write(to: jsonURL)

        let migrated = MigrationHelper.migrateIfNeeded(jsonDirectory: tempDir, context: context)
        XCTAssertTrue(migrated)

        // Verify entities in Core Data
        let request = NSFetchRequest<TaskItemEntity>(entityName: "TaskItemEntity")
        let entities = try context.fetch(request)
        XCTAssertEqual(entities.count, 2)

        // Verify old file renamed
        XCTAssertFalse(FileManager.default.fileExists(atPath: jsonURL.path))
        let migratedURL = tempDir.appendingPathComponent("tasks.json.migrated")
        XCTAssertTrue(FileManager.default.fileExists(atPath: migratedURL.path))
    }

    func testNoMigrationWhenNoJSON() {
        let migrated = MigrationHelper.migrateIfNeeded(jsonDirectory: tempDir, context: context)
        XCTAssertFalse(migrated)
    }

    func testNoMigrationWhenAlreadyMigrated() throws {
        // Create .migrated file (already migrated)
        let migratedURL = tempDir.appendingPathComponent("tasks.json.migrated")
        try "done".write(to: migratedURL, atomically: true, encoding: .utf8)

        let migrated = MigrationHelper.migrateIfNeeded(jsonDirectory: tempDir, context: context)
        XCTAssertFalse(migrated)
    }
}
```

**Step 2: 运行测试确认失败**

```bash
xcodebuild test -scheme GroTask -destination 'platform=macOS'
```

Expected: FAIL — `MigrationHelper` 未定义。

**Step 3: 实现 MigrationHelper**

创建 `Shared/Persistence/MigrationHelper.swift`：

```swift
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
```

**Step 4: 运行测试确认通过**

```bash
xcodebuild test -scheme GroTask -destination 'platform=macOS'
```

Expected: 全部通过。

**Step 5: 提交**

```bash
git add -A
git commit -m "feat: add MigrationHelper for JSON to Core Data migration"
```

---

### Task 6: 更新 macOS 入口调用迁移 + entitlements

**Files:**
- Modify: `macOS/GroTaskApp.swift`
- Modify: `macOS/GroTask.entitlements`

**Step 1: 更新 entitlements 添加 iCloud**

将 `macOS/GroTask.entitlements` 更新为：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.grotask.app</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

**Step 2: 更新 macOS App 入口**

修改 `macOS/GroTaskApp.swift` 中的 `AppDelegate`，使用 PersistenceController 并触发迁移：

```swift
import SwiftUI

@main
struct GroTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private let store: TaskStore

    override init() {
        // 触发迁移
        MigrationHelper.migrateIfNeeded(context: PersistenceController.shared.container.viewContext)
        self.store = TaskStore()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        positionNearStatusItem()
        panel.makeKeyAndOrderFront(nil)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "checklist",
                accessibilityDescription: "GroTask"
            )
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPanel() {
        panel = FloatingPanel {
            TaskPopoverView(store: self.store)
        }
    }

    @objc private func togglePanel() {
        panel.makeKeyAndOrderFront(nil)
    }

    private func positionNearStatusItem() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let buttonRect = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        let x = buttonRect.midX - panelWidth / 2
        let y = buttonRect.minY - panelHeight - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
```

**Step 3: 编译验证**

```bash
xcodegen generate
xcodebuild -scheme GroTask -destination 'platform=macOS' build
```

Expected: 编译成功。

**Step 4: 运行测试**

```bash
xcodebuild test -scheme GroTask -destination 'platform=macOS'
```

Expected: 全部通过。

**Step 5: 提交**

```bash
git add -A
git commit -m "feat: integrate Core Data + CloudKit into macOS app entry"
```

---

### Task 7: 添加 iOS Target 和入口

**Files:**
- Create: `iOS/GroTaskiOSApp.swift`
- Create: `iOS/GroTaskiOS.entitlements`
- Modify: `project.yml`

**Step 1: 创建 iOS entitlements**

创建 `iOS/GroTaskiOS.entitlements`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.grotask.app</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

**Step 2: 创建 iOS App 入口**

创建 `iOS/GroTaskiOSApp.swift`：

```swift
import SwiftUI

@main
struct GroTaskiOSApp: App {
    let store: TaskStore

    init() {
        MigrationHelper.migrateIfNeeded(context: PersistenceController.shared.container.viewContext)
        self.store = TaskStore()
    }

    var body: some Scene {
        WindowGroup {
            TaskListView(store: store)
        }
    }
}
```

**Step 3: 更新 project.yml 添加 iOS target**

在 `project.yml` 的 targets 中添加：

```yaml
  GroTaskiOS:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Shared
      - path: iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.grotask.ios
        PRODUCT_NAME: GroTask
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        CODE_SIGN_ENTITLEMENTS: iOS/GroTaskiOS.entitlements
        INFOPLIST_KEY_UILaunchScreen_Generation: true
        INFOPLIST_KEY_UISupportedInterfaceOrientations: "UIInterfaceOrientationPortrait"
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        GENERATE_INFOPLIST_FILE: "YES"
        SWIFT_VERSION: "5.9"
```

**Step 4: 创建占位 TaskListView（让编译通过）**

创建 `iOS/Views/TaskListView.swift`：

```swift
import SwiftUI

struct TaskListView: View {
    @State var store: TaskStore

    var body: some View {
        Text("GroTask")
    }
}
```

**Step 5: 生成项目并编译两个 target**

```bash
xcodegen generate
xcodebuild -scheme GroTask -destination 'platform=macOS' build
xcodebuild -scheme GroTaskiOS -destination 'generic/platform=iOS Simulator' build
```

Expected: 两个 target 都编译成功。

**Step 6: 提交**

```bash
git add -A
git commit -m "feat: add iOS target with shared Core Data persistence"
```

---

### Task 8: 实现 iOS TaskListView

**Files:**
- Modify: `iOS/Views/TaskListView.swift`
- Create: `iOS/Views/TaskRowView.swift`

**Step 1: 实现 iOS TaskRowView**

创建 `iOS/Views/TaskRowView.swift`：

```swift
import SwiftUI

struct iOSTaskRowView: View {
    let task: TaskItem
    let onCycleStatus: () -> Void
    let onDelete: () -> Void
    let onToggleCategory: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 状态指示
            if task.status == .todo {
                Circle()
                    .fill(task.category.color)
                    .frame(width: 10, height: 10)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }

            // 标题
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.status == .done ? .tertiary : .primary)
                    .strikethrough(task.status == .done)
                    .lineLimit(2)

                if task.status == .done, let completedAt = task.completedAt {
                    Text(completedAt, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                onCycleStatus()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .contextMenu {
            if task.status == .todo {
                Button {
                    withAnimation { onTogglePin() }
                } label: {
                    Label(
                        task.isPinned ? "取消置顶" : "置顶到今天",
                        systemImage: task.isPinned ? "pin.slash" : "pin"
                    )
                }

                Button {
                    withAnimation { onToggleCategory() }
                } label: {
                    Label(
                        "切换为\(task.category.next.label)",
                        systemImage: "circle.fill"
                    )
                }
            }

            Button(role: .destructive, action: onDelete) {
                Label("删除任务", systemImage: "trash")
            }
        }
    }
}
```

**Step 2: 实现 iOS TaskListView**

将 `iOS/Views/TaskListView.swift` 替换为：

```swift
import SwiftUI

struct TaskListView: View {
    @State var store: TaskStore
    @State private var newTaskTitle = ""
    @State private var newTaskCategory: TaskCategory = .work
    @State private var isDoneExpanded = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                taskList
                inputBar
            }
            .navigationTitle("GroTask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isInputFocused = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            let pinned = store.pinnedTasks
            if !pinned.isEmpty {
                Section {
                    taskRows(pinned)
                } header: {
                    Label("今天", systemImage: "pin.fill")
                }
            }

            let unpinned = store.unpinnedTasks
            if !unpinned.isEmpty {
                Section("待办") {
                    taskRows(unpinned)
                }
            }

            let done = store.doneTasks
            if !done.isEmpty {
                Section {
                    if isDoneExpanded {
                        taskRows(done)
                    }
                } header: {
                    Button {
                        withAnimation { isDoneExpanded.toggle() }
                    } label: {
                        HStack {
                            Text("已完成")
                            Spacer()
                            Text("\(done.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: isDoneExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.bottom, 60) // 为底部输入栏留空间
    }

    @ViewBuilder
    private func taskRows(_ tasks: [TaskItem]) -> some View {
        ForEach(tasks) { task in
            iOSTaskRowView(
                task: task,
                onCycleStatus: {
                    withAnimation { store.cycleStatus(id: task.id) }
                },
                onDelete: {
                    withAnimation { store.deleteTask(id: task.id) }
                },
                onToggleCategory: {
                    withAnimation { store.toggleCategory(id: task.id) }
                },
                onTogglePin: {
                    withAnimation { store.togglePin(id: task.id) }
                }
            )
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    newTaskCategory = newTaskCategory.next
                }
            } label: {
                Circle()
                    .fill(newTaskCategory.color)
                    .frame(width: 10, height: 10)
            }

            TextField("新任务...", text: $newTaskTitle)
                .focused($isInputFocused)
                .onSubmit { addTask() }

            if !newTaskTitle.isEmpty {
                Button(action: addTask) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            store.addTask(title: trimmed, category: newTaskCategory)
        }
        newTaskTitle = ""
    }
}
```

**Step 3: 编译 iOS target**

```bash
xcodegen generate
xcodebuild -scheme GroTaskiOS -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: 编译成功。

**Step 4: 提交**

```bash
git add -A
git commit -m "feat: implement iOS TaskListView and TaskRowView"
```

---

### Task 9: 清理旧的 GroTask 目录

**Files:**
- Delete: `GroTask/` 目录（已全部移至 Shared/ 和 macOS/）

**Step 1: 确认旧目录可以删除**

检查 `GroTask/` 目录是否还有文件被引用。在 Task 1 中已经将所有文件移走，此目录应为空或仅剩不需要的残留。

```bash
ls -la GroTask/
```

如果仍有 `Models/`、`Views/`、`ViewModels/` 空目录，删除：

```bash
rm -rf GroTask/Models GroTask/Views GroTask/ViewModels
```

保留 `GroTask/` 目录如果 XcodeGen 不再引用它（确认 project.yml 中无引用后可完全删除）。

**Step 2: 编译验证两个 target**

```bash
xcodegen generate
xcodebuild -scheme GroTask -destination 'platform=macOS' build
xcodebuild -scheme GroTaskiOS -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: 两个 target 都编译成功。

**Step 3: 运行全部测试**

```bash
xcodebuild test -scheme GroTask -destination 'platform=macOS'
```

Expected: 全部通过。

**Step 4: 提交**

```bash
git add -A
git commit -m "chore: clean up old GroTask directory after restructure"
```

---

## 实现顺序依赖

```
Task 1 (目录重组)
  └─→ Task 2 (Core Data 模型)
       └─→ Task 3 (PersistenceController)
            └─→ Task 4 (重写 TaskStore)
            └─→ Task 5 (迁移工具)
                 └─→ Task 6 (macOS 入口更新)
                 └─→ Task 7 (iOS Target)
                      └─→ Task 8 (iOS 界面)
                           └─→ Task 9 (清理)
```

# TaskTimeScope 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 GroTask 新增任务时间视角维度（快速/今天/随时/将来），与现有工作/生活分类正交组合，列表按时间视角分组展示。

**Architecture:** 新增 `TaskTimeScope` 枚举与 `TaskCategory` 平行，Core Data 轻量迁移加一个 `timeScopeRaw: Int16` 字段（默认值 2 = anytime）。UI 层将现有的"置顶/待办/已完成"三段式列表改为"置顶 / ⚡快速 / ☀️今天 / 👌随时 / 💭将来 / ✅已完成"分组展示，每组可展开/收起。

**Tech Stack:** Swift, SwiftUI, Core Data, CloudKit, XCTest

---

## Task 1: 新增 TaskTimeScope 枚举和模型字段

**Files:**
- Modify: `Shared/Models/TaskItem.swift`
- Test: `GroTaskTests/TaskItemTests.swift`

**Step 1: 写 TaskTimeScope 测试**

在 `GroTaskTests/TaskItemTests.swift` 末尾新增：

```swift
final class TaskTimeScopeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(TaskTimeScope.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(TaskTimeScope.quick.rawValue, 0)
        XCTAssertEqual(TaskTimeScope.today.rawValue, 1)
        XCTAssertEqual(TaskTimeScope.anytime.rawValue, 2)
        XCTAssertEqual(TaskTimeScope.someday.rawValue, 3)
    }

    func testLabels() {
        XCTAssertEqual(TaskTimeScope.quick.label, "快速")
        XCTAssertEqual(TaskTimeScope.today.label, "今天")
        XCTAssertEqual(TaskTimeScope.anytime.label, "随时")
        XCTAssertEqual(TaskTimeScope.someday.label, "将来")
    }

    func testSymbolNames() {
        XCTAssertFalse(TaskTimeScope.quick.symbolName.isEmpty)
        XCTAssertFalse(TaskTimeScope.today.symbolName.isEmpty)
        XCTAssertFalse(TaskTimeScope.anytime.symbolName.isEmpty)
        XCTAssertFalse(TaskTimeScope.someday.symbolName.isEmpty)
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for scope in TaskTimeScope.allCases {
            let data = try encoder.encode(scope)
            let decoded = try decoder.decode(TaskTimeScope.self, from: data)
            XCTAssertEqual(decoded, scope)
        }
    }
}
```

同时更新 `TaskItemTests` 中的测试：

```swift
// 在 testInitDefaults 中新增断言：
XCTAssertEqual(task.timeScope, .anytime)

// 新增测试方法：
func testInitWithTimeScope() {
    let task = TaskItem(title: "Quick task", timeScope: .quick)
    XCTAssertEqual(task.timeScope, .quick)
}

// 在 testCodableRoundTrip 中新增断言：
XCTAssertEqual(decoded.timeScope, task.timeScope)
```

**Step 2: 运行测试确认失败**

Run: `xcodebuild test -scheme GroTask -destination "platform=macOS" -only-testing:GroTaskTests/TaskTimeScopeTests -only-testing:GroTaskTests/TaskItemTests 2>&1 | tail -20`
Expected: 编译失败，`TaskTimeScope` 未定义

**Step 3: 实现 TaskTimeScope 枚举**

在 `Shared/Models/TaskItem.swift` 的 `TaskCategory` 和 `TaskStatus` 之间插入（第 35 行之后）：

```swift
// MARK: - TaskTimeScope

enum TaskTimeScope: Int, CaseIterable, Identifiable, Codable {
    case quick   = 0
    case today   = 1
    case anytime = 2
    case someday = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .quick:   return "快速"
        case .today:   return "今天"
        case .anytime: return "随时"
        case .someday: return "将来"
        }
    }

    var symbolName: String {
        switch self {
        case .quick:   return "bolt.fill"
        case .today:   return "sun.max.fill"
        case .anytime: return "hand.thumbsup.fill"
        case .someday: return "cloud.fill"
        }
    }

    var color: Color {
        switch self {
        case .quick:   return Color(.systemYellow)
        case .today:   return Color(.systemRed)
        case .anytime: return Color(.systemGreen)
        case .someday: return Color(.systemGray)
        }
    }
}
```

**Step 4: 给 TaskItem 添加 timeScope 字段**

在 `TaskItem` 结构体中：

1. 在属性列表中加 `var timeScope: TaskTimeScope`（第 64 行 `var isPinned` 之后）
2. 在简便初始化方法签名中加参数 `timeScope: TaskTimeScope = .anytime`，body 中加 `self.timeScope = timeScope`
3. 在完整初始化方法签名中加参数 `timeScope: TaskTimeScope`，body 中加 `self.timeScope = timeScope`

**Step 5: 运行测试确认通过**

Run: `xcodebuild test -scheme GroTask -destination "platform=macOS" -only-testing:GroTaskTests/TaskTimeScopeTests -only-testing:GroTaskTests/TaskItemTests 2>&1 | tail -20`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add Shared/Models/TaskItem.swift GroTaskTests/TaskItemTests.swift
git commit -m "feat: add TaskTimeScope enum and timeScope field to TaskItem"
```

---

## Task 2: Core Data 模型迁移 + Entity 映射

**Files:**
- Modify: `Shared/Persistence/GroTask.xcdatamodeld/GroTask.xcdatamodel/contents`
- Modify: `Shared/Persistence/TaskItemEntity.swift`
- Modify: `Shared/Persistence/MigrationHelper.swift`

**Step 1: 给 Core Data 模型添加 timeScopeRaw 属性**

在 `GroTask.xcdatamodel/contents` 的 `<entity>` 中，在 `isPinned` 属性后面添加：

```xml
<attribute name="timeScopeRaw" attributeType="Integer 16" defaultValueString="2" usesScalarValueType="YES"/>
```

默认值 2 = anytime，这样旧数据自动获得「随时」视角。CloudKit 兼容（新字段有默认值，旧客户端忽略）。

**Step 2: 更新 TaskItemEntity.swift**

在 `TaskItemEntity` 类中新增属性：

```swift
@NSManaged public var timeScopeRaw: Int16
```

在 extension 中新增计算属性：

```swift
var timeScope: TaskTimeScope {
    get { TaskTimeScope(rawValue: Int(timeScopeRaw)) ?? .anytime }
    set { timeScopeRaw = Int16(newValue.rawValue) }
}
```

更新 `toTaskItem()` 方法，在参数中加入 `timeScope: timeScope`。

**Step 3: 更新 MigrationHelper.swift**

在 `migrateIfNeeded` 方法的 for 循环中，`entity.completedAt = task.completedAt` 之后加一行：

```swift
entity.timeScopeRaw = Int16(task.timeScope.rawValue)
```

**Step 4: 运行全部测试确认通过**

Run: `xcodebuild test -scheme GroTask -destination "platform=macOS" 2>&1 | tail -20`
Expected: ALL PASS（Core Data 轻量迁移自动完成，因为只添加了有默认值的可选字段）

**Step 5: Commit**

```bash
git add Shared/Persistence/
git commit -m "feat: add timeScopeRaw to Core Data model and entity mapping"
```

---

## Task 3: TaskStore 新增时间视角的 CRUD 和分组查询

**Files:**
- Modify: `Shared/ViewModels/TaskStore.swift`
- Test: `GroTaskTests/TaskStoreTests.swift`

**Step 1: 写 TaskStore 时间视角测试**

在 `GroTaskTests/TaskStoreTests.swift` 末尾新增测试方法：

```swift
func testAddTaskWithTimeScope() {
    store.addTask(title: "Quick task", category: .work, timeScope: .quick)
    XCTAssertEqual(store.tasks[0].timeScope, .quick)
}

func testAddTaskDefaultTimeScope() {
    store.addTask(title: "Default scope")
    XCTAssertEqual(store.tasks[0].timeScope, .anytime)
}

func testSetTimeScope() {
    store.addTask(title: "Change scope")
    let id = store.tasks[0].id
    XCTAssertEqual(store.tasks[0].timeScope, .anytime)

    store.setTimeScope(id: id, scope: .today)
    XCTAssertEqual(store.tasks[0].timeScope, .today)
}

func testTasksForTimeScope() {
    store.addTask(title: "Quick one", category: .work, timeScope: .quick)
    store.addTask(title: "Today one", category: .work, timeScope: .today)
    store.addTask(title: "Anytime one", category: .work, timeScope: .anytime)
    store.addTask(title: "Someday one", category: .work, timeScope: .someday)

    XCTAssertEqual(store.tasks(for: .quick).count, 1)
    XCTAssertEqual(store.tasks(for: .today).count, 1)
    XCTAssertEqual(store.tasks(for: .anytime).count, 1)
    XCTAssertEqual(store.tasks(for: .someday).count, 1)
}

func testTasksForTimeScopeExcludesDone() {
    store.addTask(title: "Done quick", category: .work, timeScope: .quick)
    store.cycleStatus(id: store.tasks[0].id)

    XCTAssertEqual(store.tasks(for: .quick).count, 0)
}

func testTasksForTimeScopeExcludesPinned() {
    store.addTask(title: "Pinned quick", category: .work, timeScope: .quick)
    store.togglePin(id: store.tasks[0].id)

    XCTAssertEqual(store.tasks(for: .quick).count, 0)
}
```

**Step 2: 运行测试确认失败**

Run: `xcodebuild test -scheme GroTask -destination "platform=macOS" -only-testing:GroTaskTests/TaskStoreTests 2>&1 | tail -20`
Expected: 编译失败

**Step 3: 实现 TaskStore 改动**

在 `TaskStore.swift` 中：

1. 修改 `addTask` 方法签名：

```swift
func addTask(title: String, category: TaskCategory = .work, timeScope: TaskTimeScope = .anytime) {
```

在方法体中 `entity.completedAt = nil` 后面加：

```swift
entity.timeScopeRaw = Int16(timeScope.rawValue)
```

2. 新增 `setTimeScope` 方法（在 `toggleCategory` 之后）：

```swift
func setTimeScope(id: UUID, scope: TaskTimeScope) {
    guard let entity = findEntity(id: id) else { return }
    entity.timeScope = scope
    save()
}
```

3. 新增按时间视角过滤的方法（在 Grouped Queries 区域）：

```swift
func tasks(for scope: TaskTimeScope) -> [TaskItem] {
    tasks
        .filter { $0.timeScope == scope && $0.status == .todo && !$0.isPinned }
        .sorted { $0.createdAt > $1.createdAt }
}
```

**Step 4: 运行测试确认通过**

Run: `xcodebuild test -scheme GroTask -destination "platform=macOS" -only-testing:GroTaskTests/TaskStoreTests 2>&1 | tail -20`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add Shared/ViewModels/TaskStore.swift GroTaskTests/TaskStoreTests.swift
git commit -m "feat: add timeScope CRUD and grouped queries to TaskStore"
```

---

## Task 4: macOS UI — 输入框时间视角选择器

**Files:**
- Modify: `macOS/Views/TaskPopoverView.swift`

**Step 1: 添加 timeScope 状态和选择器**

在 `TaskPopoverView` 中：

1. 新增状态变量（在 `newTaskCategory` 之后）：

```swift
@State private var newTaskTimeScope: TaskTimeScope = .anytime
```

2. 在输入框区域（第 79-103 行 HStack）中，在 category 圆点按钮之后、TextField 之前，添加时间视角选择器：

```swift
Button {
    withAnimation(.easeInOut(duration: 0.15)) {
        let allCases = TaskTimeScope.allCases
        let currentIndex = allCases.firstIndex(of: newTaskTimeScope) ?? 0
        newTaskTimeScope = allCases[(currentIndex + 1) % allCases.count]
    }
} label: {
    Image(systemName: newTaskTimeScope.symbolName)
        .font(.caption)
        .foregroundStyle(newTaskTimeScope.color)
}
.buttonStyle(.plain)
.frame(width: 24, height: 24)
.help(newTaskTimeScope.label)
.accessibilityLabel("时间视角：\(newTaskTimeScope.label)")
```

3. 修改 `addTask()` 方法，传入 timeScope：

```swift
private func addTask() {
    let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
        store.addTask(title: trimmed, category: newTaskCategory, timeScope: newTaskTimeScope)
    }
    newTaskTitle = ""
}
```

**Step 2: 构建确认编译通过**

Run: `xcodebuild build -scheme GroTask -configuration Debug 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add macOS/Views/TaskPopoverView.swift
git commit -m "feat(macOS): add timeScope selector to quick-add input"
```

---

## Task 5: macOS UI — 列表改为分组展示

**Files:**
- Modify: `macOS/Views/TaskPopoverView.swift`

**Step 1: 添加分组展开/收起状态**

替换现有的 `isDoneExpanded` 为更完整的展开状态管理。在状态变量区域添加：

```swift
@State private var collapsedScopes: Set<TaskTimeScope> = [.someday]
```

**Step 2: 重写列表区域**

将 `ScrollView` 内的 `LazyVStack` 内容替换为分组展示逻辑：

```swift
ScrollView {
    LazyVStack(spacing: 0) {
        // 置顶区
        let pinned = store.pinnedTasks
        if !pinned.isEmpty {
            pinnedSectionHeader(count: pinned.count)
            taskRows(pinned)
        }

        // 按时间视角分组
        ForEach(TaskTimeScope.allCases) { scope in
            let scopeTasks = store.tasks(for: scope)
            if !scopeTasks.isEmpty {
                timeScopeSectionHeader(scope: scope, count: scopeTasks.count)
                if !collapsedScopes.contains(scope) {
                    taskRows(scopeTasks)
                }
            }
        }

        // 已完成区
        let done = store.doneTasks
        if !done.isEmpty {
            doneSectionHeader(count: done.count)
            if isDoneExpanded {
                taskRows(done)
            }
        }
    }
    .padding(.vertical, 4)
}
```

**Step 3: 新增 timeScopeSectionHeader 方法**

在 `sectionHeader` 方法附近新增：

```swift
private func timeScopeSectionHeader(scope: TaskTimeScope, count: Int) -> some View {
    Button {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedScopes.contains(scope) {
                collapsedScopes.remove(scope)
            } else {
                collapsedScopes.insert(scope)
            }
        }
    } label: {
        HStack(spacing: 4) {
            Image(systemName: scope.symbolName)
                .font(.caption2)
                .foregroundStyle(scope.color)

            Text(scope.label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            Spacer()

            Text("\(count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.quaternary)

            Image(systemName: "chevron.down")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.quaternary)
                .rotationEffect(collapsedScopes.contains(scope) ? .degrees(-90) : .zero)
                .animation(.easeInOut(duration: 0.2), value: collapsedScopes.contains(scope))
        }
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 16)
    .padding(.top, 10)
    .padding(.bottom, 4)
}
```

**Step 4: 删除不再需要的 `sectionHeader(title:count:)` 方法**

现有的 `sectionHeader(title: "待办", count:)` 不再使用，移除它（第 213-229 行）。

**Step 5: 构建确认编译通过**

Run: `xcodebuild build -scheme GroTask -configuration Debug 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add macOS/Views/TaskPopoverView.swift
git commit -m "feat(macOS): group task list by time scope with collapsible sections"
```

---

## Task 6: macOS TaskRowView — 右键菜单切换视角

**Files:**
- Modify: `macOS/Views/TaskRowView.swift`

**Step 1: 添加 onSetTimeScope 回调**

在 `TaskRowView` 中：

1. 新增属性（在 `onUpdateTitle` 之后）：

```swift
let onSetTimeScope: (TaskTimeScope) -> Void
```

2. 在 `.contextMenu` 中，"切换为生活/工作" 按钮之后、删除按钮之前，添加时间视角菜单：

```swift
Menu {
    ForEach(TaskTimeScope.allCases) { scope in
        if scope != task.timeScope {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onSetTimeScope(scope)
                }
            } label: {
                Label(scope.label, systemImage: scope.symbolName)
            }
        }
    }
} label: {
    Label("时间视角", systemImage: "clock")
}
```

3. 更新 `.id()` modifier 加入 timeScope：

```swift
.id("\(task.id)-\(task.status)-\(task.isPinned)-\(task.category)-\(task.timeScope)")
```

4. 更新 `.accessibilityValue`：

```swift
.accessibilityValue("\(task.category.label)，\(task.timeScope.label)，\(task.status.label)")
```

**Step 2: 更新 TaskPopoverView 中的 TaskRowView 调用**

在 `TaskPopoverView.swift` 的 `taskRows` 方法中，`TaskRowView` 初始化加入新回调：

```swift
onSetTimeScope: { scope in
    withAnimation(.easeInOut(duration: 0.15)) {
        store.setTimeScope(id: task.id, scope: scope)
    }
}
```

**Step 3: 构建确认编译通过**

Run: `xcodebuild build -scheme GroTask -configuration Debug 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add macOS/Views/TaskRowView.swift macOS/Views/TaskPopoverView.swift
git commit -m "feat(macOS): add time scope context menu to task rows"
```

---

## Task 7: iOS UI — 输入框时间视角选择器

**Files:**
- Modify: `iOS/Views/TaskListView.swift`

**Step 1: 添加状态和选择器**

在 `TaskListView` 中：

1. 新增状态变量：

```swift
@State private var newTaskTimeScope: TaskTimeScope = .anytime
```

2. 在 `inputBar` 的 HStack 中，category 圆点按钮之后、TextField 之前，添加时间视角按钮：

```swift
Button {
    withAnimation(.easeInOut(duration: 0.15)) {
        let allCases = TaskTimeScope.allCases
        let currentIndex = allCases.firstIndex(of: newTaskTimeScope) ?? 0
        newTaskTimeScope = allCases[(currentIndex + 1) % allCases.count]
    }
} label: {
    Image(systemName: newTaskTimeScope.symbolName)
        .font(.caption)
        .foregroundStyle(newTaskTimeScope.color)
}
.buttonStyle(.plain)
.frame(width: 44, height: 44)
.accessibilityLabel("时间视角：\(newTaskTimeScope.label)")
.accessibilityHint("双击切换时间视角")
```

3. 修改 `addTask()` 方法传入 timeScope：

```swift
private func addTask() {
    let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    withAnimation {
        store.addTask(title: trimmed, category: newTaskCategory, timeScope: newTaskTimeScope)
    }
    newTaskTitle = ""
}
```

**Step 2: 构建确认编译通过**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add iOS/Views/TaskListView.swift
git commit -m "feat(iOS): add timeScope selector to input bar"
```

---

## Task 8: iOS UI — 列表改为分组展示

**Files:**
- Modify: `iOS/Views/TaskListView.swift`

**Step 1: 添加分组展开/收起状态**

```swift
@State private var collapsedScopes: Set<TaskTimeScope> = [.someday]
```

**Step 2: 重写 taskList**

将 `List` 内容替换为分组展示：

```swift
List {
    // 置顶区
    let pinned = store.pinnedTasks
    if !pinned.isEmpty {
        Section {
            taskRows(pinned)
        } header: {
            Label("置顶", systemImage: "pin.fill")
        }
    }

    // 按时间视角分组
    ForEach(TaskTimeScope.allCases) { scope in
        let scopeTasks = store.tasks(for: scope)
        if !scopeTasks.isEmpty {
            Section {
                if !collapsedScopes.contains(scope) {
                    taskRows(scopeTasks)
                }
            } header: {
                Button {
                    withAnimation {
                        if collapsedScopes.contains(scope) {
                            collapsedScopes.remove(scope)
                        } else {
                            collapsedScopes.insert(scope)
                        }
                    }
                } label: {
                    HStack {
                        Label(scope.label, systemImage: scope.symbolName)
                            .foregroundStyle(scope.color)
                        Spacer()
                        Text("\(scopeTasks.count)")
                            .foregroundStyle(.tertiary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .rotationEffect(collapsedScopes.contains(scope) ? .degrees(-90) : .zero)
                            .animation(.easeInOut(duration: 0.2), value: collapsedScopes.contains(scope))
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // 已完成区
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
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(isDoneExpanded ? .degrees(-180) : .zero)
                        .animation(.easeInOut(duration: 0.2), value: isDoneExpanded)
                }
            }
            .foregroundStyle(.primary)
        }
    }
}
.listStyle(.insetGrouped)
.contentMargins(.bottom, 70)
.scrollDismissesKeyboard(.interactively)
```

**Step 3: 构建确认编译通过**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add iOS/Views/TaskListView.swift
git commit -m "feat(iOS): group task list by time scope with collapsible sections"
```

---

## Task 9: iOS TaskRowView — 右键菜单切换视角

**Files:**
- Modify: `iOS/Views/TaskRowView.swift`
- Modify: `iOS/Views/TaskListView.swift`

**Step 1: 添加 onSetTimeScope 回调**

在 `iOSTaskRowView` 中：

1. 新增属性：

```swift
let onSetTimeScope: (TaskTimeScope) -> Void
```

2. 在 `.contextMenu` 中，"切换为生活/工作" 之后、删除之前，添加：

```swift
Menu {
    ForEach(TaskTimeScope.allCases) { scope in
        if scope != task.timeScope {
            Button {
                withAnimation { onSetTimeScope(scope) }
            } label: {
                Label(scope.label, systemImage: scope.symbolName)
            }
        }
    }
} label: {
    Label("时间视角", systemImage: "clock")
}
```

3. 更新 `.accessibilityValue`：

```swift
.accessibilityValue("\(task.category.label)，\(task.timeScope.label)，\(task.status.label)")
```

**Step 2: 更新 TaskListView 中的 iOSTaskRowView 调用**

在 `taskRows` 方法中新增回调：

```swift
onSetTimeScope: { scope in
    withAnimation { store.setTimeScope(id: task.id, scope: scope) }
}
```

**Step 3: 构建确认编译通过**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add iOS/Views/TaskRowView.swift iOS/Views/TaskListView.swift
git commit -m "feat(iOS): add time scope context menu to task rows"
```

---

## Task 10: 全量测试 + 最终验证

**Step 1: 运行全部测试**

Run: `xcodebuild test -scheme GroTask -destination "platform=macOS" 2>&1 | tail -30`
Expected: ALL TESTS PASS

**Step 2: 构建 macOS**

Run: `xcodebuild build -scheme GroTask -configuration Debug 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: 构建 iOS**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 4: Commit（如有遗漏修复）**

```bash
git add -A
git commit -m "feat: complete TaskTimeScope implementation across both platforms"
```

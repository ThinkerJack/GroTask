# GroTask CloudKit 同步重构技术方案

> 日期：2026-03-15
> 状态：草案 v3

## 一、问题诊断

### 1.1 用户感知

两台 Mac + iPhone 之间同步不及时，冷启动后数据不是最新，需要等待较长时间才能看到其他设备的变更。

### 1.2 根因分析

| # | 问题 | 位置 | 严重度 |
|---|------|------|--------|
| 1 | **双轨同步冲突**：NSPersistentCloudKitContainer 自动同步 + CloudKitPoller 手动拉 CKRecord 回写 Core Data，两套机制并存，change token 各自维护，互相干扰 | `CloudKitPoller.swift` | 致命 |
| 2 | **推送环境不一致**：iOS `aps-environment = development`，macOS `com.apple.developer.aps-environment = production`，推送通道不同，静默推送无法正常触发 | `GroTaskiOS.entitlements:5` / `GroTask.entitlements:9` | 致命 |
| 3 | **iOS 未处理远程通知**：`AppDelegateiOS` 只注册了远程通知，未实现 `didReceiveRemoteNotification` 回调 | `GroTaskiOSApp.swift:21` | 高 |
| 4 | **缺少前台/冷启动触发**：iOS 无 `scenePhase == .active` 时的刷新，冷启动后依赖系统自动同步，无主动拉取 | `GroTaskiOSApp.swift` | 高 |
| 5 | **Poller change token 不持久化**：内存态，重启即丢，冷启动后不知道同步到哪里 | `CloudKitPoller.swift:11` | 中 |
| 6 | **fetchAll 线程安全**：`contextDidChange` 可能在后台线程触发，直接更新驱动 SwiftUI 的 `tasks` 数组 | `TaskStore.swift:36` | 中 |

### 1.3 现有同步链路

```
本地写入 → context.save()
              ↓
    NSPersistentCloudKitContainer 自动上行 → CloudKit
              ↓
    CloudKit 变更到达 → 系统自动合并到 viewContext
              ↓                              ↓
    contextDidChange 通知               CloudKitPoller 10s 轮询
              ↓                              ↓
    fetchAll() 刷新 UI              手动拉 CKRecord → 手动写 Core Data
                                         ↓
                                   再次触发 contextDidChange
                                         ↓
                                   再次 fetchAll()（重复）
```

问题：两条下行路径并存，Poller 的手动写入会和系统自动合并产生冲突。

## 二、目标

1. **冷启动可靠**：打开 App 后先显示本地缓存，待 CloudKit import 完成后自动刷新（容忍 1-3 秒 loading）
2. **前台及时**：其他设备变更在 5-15 秒内可见（依赖 CloudKit 静默推送延迟）
3. **用户可控**：提供手动刷新能力作为兜底
4. **架构清晰**：单一同步链路，无双轨冲突

> **关于"最新"的定义**：本方案中"import 完成后数据最新"指的是"当前这批 import 已完成并写入本地 store"，不等价于"云端已经没有后续变更"或"多设备全局绝对一致"。CloudKit 是最终一致模型，后续变更会在下一批 import 中到达。

## 三、方案设计

### 3.1 整体策略：回归 NSPersistentCloudKitContainer 单一同步

删除 CloudKitPoller，完全依赖 Apple 官方同步机制。

**UI 刷新的唯一权威信号**是 `eventChangedNotification` 的 `.import` 完成事件。其他通知（`contextDidChange`）仅用于本地写入后的即时反馈。

```
本地写入 → context.save()
              ↓
    NSPersistentCloudKitContainer 自动上行 → CloudKit

    CloudKit 变更到达
              ↓
    NSPersistentCloudKitContainer 执行 import
              ↓
    import 完成 → eventChangedNotification (.import, endDate != nil, error == nil)
              ↓
    refreshAllObjects() + fetchAll()
              ↓
    SwiftUI 重新渲染
```

### 3.2 变更清单

#### 第一步：Entitlements 分环境配置

iOS 和 macOS 的 aps-environment key 名称本就不同（平台差异），不需要统一 key 名。

当前所有设备均为 Xcode 直装，macOS 的 aps-environment 需要改为 `development`。但为了避免后续公证分发时再手动改回 `production`，**直接在 Phase 1 做 Debug/Release 分离**。

**文件：`iOS/GroTaskiOS.entitlements`** — 不改动

iOS 的 key 名为 `aps-environment`（不带 `com.apple.developer` 前缀），这是 iOS 平台的标准写法。当前值为 `development`，Xcode 直装正确，**保持不变**。

**macOS 拆分为两份 entitlements 文件：**

新建 `macOS/GroTask-Debug.entitlements`（从现有文件复制，aps-environment 改为 development）：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.application-identifier</key>
    <string>4KT56S2BX6.com.grotask.app</string>
    <key>com.apple.developer.team-identifier</key>
    <string>4KT56S2BX6</string>
    <key>com.apple.developer.aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.grotask.app</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

保留 `macOS/GroTask.entitlements` 作为 Release 版本（aps-environment = production），重命名为 `macOS/GroTask-Release.entitlements`。

**修改 `project.yml`：**

```yaml
targets:
  GroTask:
    settings:
      base:
        INFOPLIST_FILE: macOS/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.grotask.app
        # ... 其他不变
      configs:
        Debug:
          CODE_SIGN_ENTITLEMENTS: macOS/GroTask-Debug.entitlements
        Release:
          CODE_SIGN_ENTITLEMENTS: macOS/GroTask-Release.entitlements
```

移除 base 中原有的 `CODE_SIGN_ENTITLEMENTS: macOS/GroTask.entitlements`。

> 这样 Xcode 直装（Debug）自动使用 development 推送环境，`notarize.sh`（Release archive）自动使用 production。无需手动切换。

#### 第二步：删除 CloudKitPoller

**删除文件：**
- `Shared/Persistence/CloudKitPoller.swift`

**修改文件：`Shared/ViewModels/TaskStore.swift`**

移除所有 Poller 相关代码：
- 删除 `private var poller: CloudKitPoller?`
- 删除 `init` 中的 Poller 初始化和 `startPolling`
- 删除 `deinit`（Poller 是唯一需要清理的资源，NotificationCenter observer 在对象释放时自动移除）

**修改文件：`project.yml`**
- `Shared/Persistence/CloudKitPoller.swift` 位于 `Shared/` 目录下，XcodeGen 使用 `path: Shared` 自动包含所有源文件，删除文件即可，project.yml 不需要额外改动。

#### 第三步：重构 TaskStore 初始化和通知监听

**调用方变更**

现有调用点：

| 调用方 | 当前写法 | 改后写法 |
|--------|----------|----------|
| `AppDelegate.init()` (macOS) | `TaskStore()` | `TaskStore()` — 不变 |
| `GroTaskiOSApp.init()` | `TaskStore()` | `TaskStore()` — 不变 |
| `TaskStore(context:)` (测试) | `TaskStore(context: testContext)` | `TaskStore(context: testContext)` — 不变 |

为了不破坏现有调用点，`TaskStore` 的公开接口保持不变。内部通过 `PersistenceController.shared.container` 获取 container 引用来监听 CloudKit 事件。测试场景（inMemory container）不是 `NSPersistentCloudKitContainer`，CloudKit 事件监听自然不会注册，不影响测试。

```swift
@Observable
final class TaskStore {

    private(set) var tasks: [TaskItem] = []
    private(set) var isSyncing: Bool = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?

    private let context: NSManagedObjectContext
    private let container: NSPersistentContainer

    convenience init() {
        let pc = PersistenceController.shared
        self.init(context: pc.container.viewContext, container: pc.container)
    }

    /// 测试用：传入 inMemory context，container 为普通 NSPersistentContainer，不会注册 CloudKit 监听
    convenience init(context: NSManagedObjectContext) {
        // 测试场景没有真实 container 引用，创建一个哑 container 占位
        // CloudKit 事件监听因 container 不是 NSPersistentCloudKitContainer 而自动跳过
        let dummyContainer = NSPersistentContainer(name: "GroTask")
        self.init(context: context, container: dummyContainer)
    }

    private init(context: NSManagedObjectContext, container: NSPersistentContainer) {
        self.context = context
        self.container = container
        fetchAll()

        // 1. 监听 context 变更（仅用于本地写入后即时反馈）
        NotificationCenter.default.addObserver(
            self, selector: #selector(contextDidChange),
            name: .NSManagedObjectContextObjectsDidChange, object: context
        )

        // 2. 监听 CloudKit import 事件（远端同步的唯一权威信号）
        if let cloudKitContainer = container as? NSPersistentCloudKitContainer {
            NotificationCenter.default.addObserver(
                self, selector: #selector(cloudKitEventChanged),
                name: NSPersistentCloudKitContainer.eventChangedNotification,
                object: cloudKitContainer
            )
        }
    }

    // ... CRUD 方法不变
}
```

**关键决策：不再监听 `NSPersistentStoreRemoteChange`**

v2 方案同时监听 `eventChangedNotification` 和 `NSPersistentStoreRemoteChange`，两者都触发 `refreshAllObjects()` + `fetchAll()`，导致一次 import 可能触发多次全量刷新，带来列表抖动和重复查询。

收口为：
- **远端同步刷新**：只认 `eventChangedNotification` 的 `.import` 完成事件
- **本地写入刷新**：只认 `contextDidChange`（由 `save()` 触发）
- `NSPersistentStoreRemoteChange` 不再监听。如果后续发现 `eventChangedNotification` 在特定 OS 版本有遗漏，再加回作为兜底，但需要加去重逻辑（比如 debounce 或 flag）而非直接双通道刷新。

**import 事件处理：**

```swift
@objc private func cloudKitEventChanged(_ notification: Notification) {
    guard let event = notification.userInfo?[
        NSPersistentCloudKitContainer.eventNotificationUserInfoKey
    ] as? NSPersistentCloudKitContainer.Event else { return }

    // 只关心 import 事件（远端数据拉到本地）
    guard event.type == .import else {
        // export 事件可用于更新"上传中"状态，按需处理
        return
    }

    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        if event.endDate == nil {
            // import 开始
            self.isSyncing = true
        } else {
            // import 结束（成功或失败）
            self.isSyncing = false
            if let error = event.error {
                self.syncError = error
                print("CloudKit import failed: \(error)")
            } else {
                self.syncError = nil
                self.lastSyncDate = Date()
                // 这批 import 已完成写入本地 store，刷新 UI
                self.context.refreshAllObjects()
                self.fetchAll()
            }
        }
    }
}

@objc private func contextDidChange(_ notification: Notification) {
    // 仅用于本地写入后即时反馈，确保主线程执行
    if Thread.isMainThread {
        fetchAll()
    } else {
        DispatchQueue.main.async { [weak self] in
            self?.fetchAll()
        }
    }
}
```

#### 第四步：重写 refreshFromStore

```swift
/// 手动刷新：丢弃 viewContext 缓存，重新从 persistent store 读取
func refreshFromStore() {
    context.refreshAllObjects()
    fetchAll()
}
```

语义：重新从本地 store 读数据到 UI。不负责从 CloudKit 拉数据。调用场景：
- 回前台时：如果后台期间 import 已完成，这里能读到最新数据
- 用户手动刷新：兜底操作，确保 UI 和本地 store 一致
- 面板打开时（macOS）：同上

#### 第五步：iOS 补齐触发点

**5.1 处理远程通知**

收到推送时 `NSPersistentCloudKitContainer` 会自行启动 import，不需要我们手动拉数据。推送回调的职责是**告诉系统这是一个 CloudKit 推送，已被处理**。数据刷新由第三步的 `eventChangedNotification` 驱动。

```swift
final class AppDelegateiOS: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [String: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // NSPersistentCloudKitContainer 自己处理 CloudKit 推送并启动 import。
        // 不需要在这里做任何刷新操作。
        // 立即告诉系统有新数据（让系统知道这个推送是有意义的，有助于后续推送的优先级）。
        // 实际的 UI 更新由 eventChangedNotification 的 .import 完成事件驱动。
        completionHandler(.newData)
    }
}
```

> **为什么立即返回 `.newData` 而不是等 import 完成**：`didReceiveRemoteNotification` 的 completion handler 的职责是告诉系统后台拉取的结果，而非等待数据处理完成。`NSPersistentCloudKitContainer` 的 import 是独立于这个回调的异步流程。人为延迟（如 `asyncAfter(3)`）既不能保证 import 完成，又浪费后台执行时间配额。返回 `.newData`（而非 `.noData`）是因为 CloudKit 推送本身就意味着有新数据到达，告诉系统这是有效推送有助于系统维持后续推送的优先级。

**5.2 前台恢复时刷新**

```swift
@Environment(\.scenePhase) private var scenePhase

var body: some Scene {
    WindowGroup {
        TaskListView(store: store)
    }
    .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
            store.refreshFromStore()
        }
    }
}
```

**5.3 macOS 面板显示时刷新（已有，保留）**

`togglePanel()` 中已调用 `store.refreshFromStore()`，保留即可。

#### 第六步（可选）：手动刷新 UI 入口

**iOS**：在 TaskListView 的列表上添加下拉刷新

```swift
List { ... }
    .refreshable {
        store.refreshFromStore()
    }
```

**macOS**：已有 — 点击 menu bar 图标时触发。可额外加快捷键 `⌘R`。

#### 第七步（可选）：同步状态指示 UI

利用第三步已维护的 `isSyncing` / `lastSyncDate` / `syncError` 状态，在 UI 上展示：

| 状态 | 显示 |
|------|------|
| `isSyncing == true` | 正在同步...（spinner） |
| `lastSyncDate != nil && syncError == nil` | 已同步（或显示时间） |
| `syncError != nil` | 同步失败（提示检查网络/iCloud） |
| 首次启动还未收到任何事件 | 不显示 |

位置建议：iOS 列表顶部小字、macOS 面板底部状态栏。

## 四、重构后的同步链路

### 4.1 本地写入路径

```
用户操作 → TaskStore.addTask/deleteTask/cycleStatus
         → context.save()
         → contextDidChange 通知 → fetchAll() 刷新 UI（本地即时可见）
         → NSPersistentCloudKitContainer 自动上行到 CloudKit（异步）
```

### 4.2 CloudKit 下行路径

```
其他设备写入 → CloudKit 变更
            → 静默推送唤醒 App（如果在后台）
            → NSPersistentCloudKitContainer 自动执行 import
            → import 进行中 → eventChangedNotification (type=import, endDate=nil)
            →                  isSyncing = true（UI 可显示同步中）
            → import 完成   → eventChangedNotification (type=import, endDate≠nil, error=nil)
            →                  refreshAllObjects() + fetchAll()
            →                  isSyncing = false, lastSyncDate = now
            → SwiftUI 重新渲染（这批 import 的数据已写入本地 store）
```

### 4.3 冷启动路径

```
App 启动
    ↓
TaskStore.init() → fetchAll()（先显示本地缓存数据，可能是旧的）
    ↓
NSPersistentCloudKitContainer 自动启动 import
    ↓
eventChangedNotification (type=import, endDate=nil) → isSyncing = true
    ↓（UI 可选显示"正在同步"）
eventChangedNotification (type=import, endDate≠nil) → refreshAllObjects() + fetchAll()
    ↓
UI 更新为这批 import 后的最新数据
```

冷启动体验：先看到本地缓存（瞬间），如果有云端变更则 1-3 秒后自动刷新。

### 4.4 通知职责分工

| 通知 | 用途 | 触发刷新 |
|------|------|----------|
| `contextDidChange` | 本地写入后即时反馈 | `fetchAll()` |
| `eventChangedNotification` (.import 完成) | 远端同步的权威信号 | `refreshAllObjects()` + `fetchAll()` |
| `NSPersistentStoreRemoteChange` | **不监听**（避免和 eventChanged 重复刷新） | — |
| `didReceiveRemoteNotification` | 仅告知系统推送已处理，不做数据操作 | — |

### 4.5 触发矩阵

| 场景 | iOS | macOS | 触发方式 | 数据新鲜度 |
|------|-----|-------|----------|------------|
| 冷启动 | ✅ | ✅ | `init()` → `fetchAll()` 显示缓存，等 import 完成后自动刷新 | import 完成后为当前批次最新 |
| 从后台回前台 | ✅ 新增 | ✅ 已有 | `scenePhase == .active` / `togglePanel()` → `refreshFromStore()` | 如果后台 import 已完成则为最新 |
| 收到静默推送 | ✅ 新增 | ✅ 已有 | 推送唤醒 → 系统自动 import → eventChangedNotification | import 完成后为当前批次最新 |
| 远端 import 完成 | ✅ 新增 | ✅ 新增 | `eventChangedNotification` (.import + endDate) → 刷新 | **核心机制** |
| 用户手动刷新 | ✅ 新增 | ✅ 已有 | 下拉刷新 / 点击 menu bar / ⌘R | 读本地 store 当前状态 |
| 本地写入后 | ✅ | ✅ | `save()` → `contextDidChange` → `fetchAll()` | 本地即时 |

## 五、文件变更汇总

| 操作 | 文件 | 说明 |
|------|------|------|
| 删除 | `Shared/Persistence/CloudKitPoller.swift` | 移除双轨同步源头 |
| 新建 | `macOS/GroTask-Debug.entitlements` | aps-environment = development |
| 重命名 | `macOS/GroTask.entitlements` → `macOS/GroTask-Release.entitlements` | aps-environment = production（保持不变） |
| 修改 | `project.yml` | macOS target 的 CODE_SIGN_ENTITLEMENTS 按 Debug/Release 区分 |
| 修改 | `Shared/ViewModels/TaskStore.swift` | 移除 Poller；新增 eventChangedNotification 监听；新增同步状态属性；收口 init 签名兼容性；线程安全；重写 refreshFromStore |
| 修改 | `iOS/GroTaskiOSApp.swift` | 添加 scenePhase 监听、didReceiveRemoteNotification |
| 可选 | iOS `TaskListView` | 添加 `.refreshable` 下拉刷新 |
| 可选 | macOS `TaskPopoverView` | 添加 `⌘R` 快捷键刷新 |
| 可选 | 两端 View 层 | 同步状态指示 UI |

> **注意**：iOS `GroTaskiOS.entitlements` 不做改动。`aps-environment`（无前缀）是 iOS 平台的标准 key 名，`com.apple.developer.aps-environment`（带前缀）是 macOS 平台的标准 key 名。

## 六、实施顺序

```
Phase 1 — 架构收敛
  ├─ 1.1 macOS entitlements 拆分为 Debug/Release，更新 project.yml
  ├─ 1.2 删除 CloudKitPoller.swift
  ├─ 1.3 TaskStore: 移除 Poller，新增 eventChangedNotification 监听，
  │      收口 init 签名（convenience init() / convenience init(context:) / private init(context:container:)）
  └─ 1.4 线程安全修复

Phase 2 — 补齐 iOS 触发点
  ├─ 2.1 AppDelegateiOS: 添加 didReceiveRemoteNotification（立即返回 .newData）
  └─ 2.2 GroTaskiOSApp: 添加 scenePhase == .active 刷新

Phase 3 — 体验增强（可选）
  ├─ 3.1 iOS 下拉刷新
  ├─ 3.2 macOS ⌘R 快捷键
  └─ 3.3 同步状态指示 UI（利用 isSyncing / lastSyncDate / syncError）
```

## 七、验证方案

1. **冷启动验证**：设备 A 新增任务 → 杀掉设备 B 进程 → 重新打开设备 B → 应先看到缓存数据，1-3 秒后自动刷新为最新（观察 import 事件日志确认 eventChangedNotification 被触发）
2. **前台恢复验证**：设备 A 新增任务 → 设备 B 切到后台等 10 秒再切回 → 应在回前台后立即显示最新数据
3. **实时同步验证**：设备 A 和 B 同时打开 → 设备 A 新增任务 → 设备 B 应在 5-15 秒内显示（取决于 CloudKit 推送延迟）
4. **删除同步验证**：设备 A 删除任务 → 设备 B 应在下次 import 完成后同步删除
5. **冲突验证**：两台设备同时修改同一任务 → 验证 merge policy 正确解决冲突，无数据丢失
6. **同步状态验证**（如果实现）：import 进行中时 UI 显示同步指示，完成后消失
7. **Debug/Release 构建验证**：Debug 构建使用 development 推送环境，Release archive 使用 production 推送环境

## 八、风险与回退

| 风险 | 概率 | 应对 |
|------|------|------|
| 删除 Poller 后在前台场景感觉变慢 | 低 | 根因是推送通道不通，修复 entitlements 后应改善。如确实慢，优先排查推送环境 |
| `refreshAllObjects()` 导致 UI 闪烁 | 中 | 可改为只 refresh 有变更的 object，或用动画平滑过渡 |
| `eventChangedNotification` 在特定 OS 版本有遗漏 | 低 | 加回 `NSPersistentStoreRemoteChange` 监听，但需加 debounce（如 0.5 秒内去重）避免重复刷新 |
| 冷启动到 import 完成之间看到旧数据 | 确定 | 这是预期行为，通过同步状态指示（Phase 3）让用户知道正在同步 |
| 测试中 `TaskStore(context:)` 创建了 dummy container | 低 | dummy container 不是 NSPersistentCloudKitContainer，CloudKit 监听不会注册，不影响测试逻辑。如需验证同步逻辑可单独写集成测试 |

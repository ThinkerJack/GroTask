# GroTask iOS 版本设计方案

## 概述

为 GroTask 添加 iOS 版本，定位为**轻量快捷输入**端，macOS 仍为主力使用端。通过 iCloud CloudKit 实现双端任务自动同步。

## 需求

- iOS 端支持查看任务列表、快速添加任务、标记完成
- macOS 与 iOS 数据实时同步（iCloud CloudKit）
- 界面风格与 macOS 版保持一致（简约单页三分区）
- V1 不做通知提醒、Widget、iPad 适配

## 技术方案：Core Data + NSPersistentCloudKitContainer

### 选型理由

- Apple 官方推荐方案，同步逻辑几乎零代码
- 自动处理冲突合并、离线缓存、增量同步
- 经过多年生产验证，成熟可靠
- 数据模型简单（单实体），Core Data 复杂性完全可控

### 备选方案（已排除）

- **CKRecord 直接操作**：需自己写同步逻辑，代码量大，本质是重造轮子
- **SwiftData + CloudKit**：框架较新，CloudKit 集成不如 Core Data 成熟

## 项目结构

```
GroTask/
├── Shared/                          # 跨平台共享代码
│   ├── Models/
│   │   └── TaskItem.swift           # TaskCategory, TaskStatus 枚举
│   ├── Persistence/
│   │   ├── GroTask.xcdatamodeld     # Core Data 模型
│   │   ├── PersistenceController.swift  # NSPersistentCloudKitContainer
│   │   └── MigrationHelper.swift    # JSON → Core Data 迁移
│   └── ViewModels/
│       └── TaskStore.swift          # 基于 Core Data 的 @Observable store
│
├── macOS/                           # macOS 专属
│   ├── GroTaskApp.swift             # AppDelegate + FloatingPanel 入口
│   ├── Views/
│   │   ├── FloatingPanel.swift
│   │   ├── TaskPopoverView.swift
│   │   └── TaskRowView.swift
│   └── GroTask.entitlements
│
├── iOS/                             # iOS 专属
│   ├── GroTaskiOSApp.swift          # iOS App 入口
│   ├── Views/
│   │   ├── TaskListView.swift       # 主列表页
│   │   └── TaskRowView.swift        # iOS 任务行
│   └── GroTaskiOS.entitlements
│
├── GroTaskTests/
└── project.yml
```

## Core Data 模型

**实体：TaskItemEntity**

| 属性 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `title` | String | 任务标题 |
| `statusRaw` | Int16 | 0 = todo, 2 = done |
| `categoryRaw` | Int16 | 0 = work, 1 = life |
| `isPinned` | Bool | 是否置顶 |
| `createdAt` | Date | 创建时间 |
| `completedAt` | Date? | 完成时间 |

## PersistenceController

- 容器类型：`NSPersistentCloudKitContainer`
- CloudKit Container ID：`iCloud.com.grotask.app`
- 自动合并：`automaticallyMergesChangesFromParent = true`
- 冲突策略：`NSMergeByPropertyObjectTrumpMergePolicy`（本地最新值优先）

## TaskStore 改造

- 从 JSON 文件读写改为 Core Data `NSManagedObjectContext` CRUD
- 对外 API 保持不变：`addTask`, `deleteTask`, `cycleStatus`, `togglePin`, `toggleCategory`
- 查询改为 `NSFetchRequest` + 排序描述符
- 监听数据变更自动刷新 UI

## 数据迁移

- 首次启动检测旧 `tasks.json` 是否存在
- 存在则批量导入到 Core Data
- 导入成功后重命名为 `tasks.json.migrated`
- 一次性迁移

## iOS 界面设计

简约单页，三分区列表：

```
┌─────────────────────────┐
│  GroTask          [+]   │  导航栏 + 添加按钮
├─────────────────────────┤
│  📌 今天                │  pinned & todo
│  │ 🔵 完成设计稿        │
│  │ 🟠 买菜             │
│                         │
│  📋 待办                │  unpinned & todo
│  │ 🔵 写周报           │
│                         │
│  ✅ 已完成（折叠）       │  done，默认折叠
│  │ ✓ 提交代码  10:30   │
├─────────────────────────┤
│ [工作 ▾]  新任务...  [↩]│  底部快速输入栏
└─────────────────────────┘
```

### 交互方式

| 操作 | macOS | iOS |
|------|-------|-----|
| 标记完成 | 点击状态按钮 | Tap 任务行 |
| 删除 | Hover 删除按钮 | 左滑删除 |
| 置顶/分类 | 右键菜单 | 长按菜单 |
| 添加任务 | 底部输入框 | 底部输入框 |

## iCloud 配置

**Entitlements（两端共用）：**
- `com.apple.developer.icloud-container-identifiers`: `["iCloud.com.grotask.app"]`
- `com.apple.developer.icloud-services`: `["CloudKit"]`

**Apple Developer 后台：**
- macOS + iOS 两个 App ID 开启 iCloud 能力
- 创建 CloudKit Container：`iCloud.com.grotask.app`
- 两个 App ID 关联同一个 Container

**project.yml 配置：**

```yaml
targets:
  GroTask:
    platform: macOS
    sources: [Shared/, macOS/]
    entitlements: macOS/GroTask.entitlements

  GroTaskiOS:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources: [Shared/, iOS/]
    entitlements: iOS/GroTaskiOS.entitlements
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.grotask.ios

  GroTaskTests:
    sources: [GroTaskTests/]
    dependencies:
      - target: GroTask
```

## 改动范围

### 改动现有文件

| 文件 | 改动 |
|------|------|
| `project.yml` | 新增 iOS target，调整 source 分组 |
| `TaskStore.swift` | 重写为 Core Data CRUD |
| 测试文件 | TaskStoreTests 适配 Core Data |

### 移动现有文件

- `TaskItem.swift` → `Shared/Models/`
- `TaskStore.swift` → `Shared/ViewModels/`
- macOS Views → `macOS/Views/`
- `GroTaskApp.swift` → `macOS/`

### 新增文件

| 文件 | 说明 |
|------|------|
| `Shared/Persistence/GroTask.xcdatamodeld` | Core Data 模型 |
| `Shared/Persistence/PersistenceController.swift` | CloudKit 容器 |
| `Shared/Persistence/MigrationHelper.swift` | JSON 迁移 |
| `iOS/GroTaskiOSApp.swift` | iOS 入口 |
| `iOS/Views/TaskListView.swift` | iOS 列表页 |
| `iOS/Views/TaskRowView.swift` | iOS 任务行 |
| `iOS/GroTaskiOS.entitlements` | iCloud 权限 |

## V1 Scope 外

- 通知提醒 → V2
- iOS Widget → V2
- iPad 适配 → V2
- Apple Watch → 暂不考虑

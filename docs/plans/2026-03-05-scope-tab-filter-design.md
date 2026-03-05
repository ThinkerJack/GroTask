# 视角 Tab 筛选设计

**Goal:** 解决任务堆积导致的视觉压力。打开面板默认只显示"今天"的任务，通过 Tab 切换查看其他视角，减少认知负荷。

**灵感来源:** Things 3 的分层时间桶 + Amazing Marvin 的隐藏全局列表理念。

---

## 交互逻辑

### Tab 选项

`今天` | `快速` | `随时` | `将来` | `全部`

### 规则

- 默认选中"今天"（每次打开面板时重置）
- 选中具体视角：显示 置顶任务 + 该视角的待办任务，无分组 header
- 选中"全部"：恢复现有分组折叠列表
- 已完成区：仅"全部"视图下显示
- 置顶任务：所有视角下都显示

### 输入框联动

- Tab 切换时，`newTaskTimeScope` 自动跟随当前选中的视角
- 选中"全部"时保持上次的 timeScope

---

## 视觉与布局

### macOS 面板 (320pt)

Tab 栏位于 Header 与 Divider 之间，紧凑胶囊按钮风格：
- 选中态：scope 对应颜色淡色背景 + 同色文字 + icon
- 未选中态：纯文字，`.secondary` 色
- 字体 `.caption`，整行高度约 28pt
- 无需水平滚动（5 个 tab 在 320pt 内放得下）

### iOS

- navigationTitle 下方同样一排 Tab
- `ScrollView(.horizontal)` + capsule 按钮
- 样式与 macOS 一致

### 空状态

当某视角没有任务时，显示轻量提示（如"今天暂无任务" + scope icon）

---

## 状态管理

```swift
@State private var selectedScope: TaskTimeScope? = .today
// nil = 全部, .today/.quick/.anytime/.someday = 具体视角
```

### 列表数据源

```
selectedScope == nil  -> 现有分组折叠逻辑（全部视图）
selectedScope != nil  -> store.pinnedTasks + store.tasks(for: scope)
```

### 输入框联动

```
Tab 切换时: newTaskTimeScope = selectedScope ?? newTaskTimeScope
```

### 无持久化

`selectedScope` 不存 UserDefaults，每次打开重置为 `.today`。刻意为之——强化聚焦习惯。

---

## 改动范围

| 文件 | 改动 |
|------|------|
| `macOS/Views/TaskPopoverView.swift` | 加 Tab 栏 + 列表条件渲染 + 输入框联动 |
| `iOS/Views/TaskListView.swift` | 同上，适配 iOS 布局 |

- 无 Core Data / 数据模型变更
- 无 TaskStore 变更
- 无 TaskRowView 变更
- 纯 UI 层改动

### 不做的事

- 不加 Tab 切换动画
- 不加手势滑动切 Tab
- 不持久化选中态
- 不改已完成任务逻辑

# TaskListView 视觉设计优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 优化 iOS 和 macOS 双平台的 TaskListView 视觉设计，提升间距、字体层级、配色和动效表现。

**Architecture:** 在现有视图结构上做精细调整（方案 A：渐进精修），不引入新文件或新抽象层。修改 4 个视图文件，遵循 Apple HIG 精致克制风格。

**Tech Stack:** SwiftUI, SF Symbols, iOS 17+ symbolEffect API

---

### Task 1: iOS TaskRowView — 间距与字体优化

**Files:**
- Modify: `iOS/Views/TaskRowView.swift:21` (HStack spacing)
- Modify: `iOS/Views/TaskRowView.swift:36` (VStack spacing)
- Modify: `iOS/Views/TaskRowView.swift:45` (已完成标题 foregroundStyle)
- Modify: `iOS/Views/TaskRowView.swift:52-53` (时间戳样式)
- Modify: `iOS/Views/TaskRowView.swift:59` (行内边距)

**Step 1: 调整 HStack spacing**

```swift
// iOS/Views/TaskRowView.swift:21
// 旧：HStack(spacing: 12) {
HStack(spacing: 10) {
```

**Step 2: 调整标题与时间戳间距**

```swift
// iOS/Views/TaskRowView.swift:36
// 旧：VStack(alignment: .leading, spacing: 2) {
VStack(alignment: .leading, spacing: 3) {
```

**Step 3: 优化已完成标题样式**

```swift
// iOS/Views/TaskRowView.swift:43-47
// 旧：
//     Text(task.title)
//         .font(.body)
//         .foregroundStyle(task.status == .done ? .tertiary : .primary)
//         .strikethrough(task.status == .done)
//         .lineLimit(2)
// 新：
Text(task.title)
    .font(.body)
    .foregroundStyle(task.status == .done ? .secondary : .primary)
    .opacity(task.status == .done ? 0.6 : 1)
    .strikethrough(task.status == .done)
    .lineLimit(2)
```

**Step 4: 优化完成时间戳可见度**

```swift
// iOS/Views/TaskRowView.swift:51-53
// 旧：
//     Text(completedAt, format: .dateTime.hour().minute())
//         .font(.caption2)
//         .foregroundStyle(.quaternary)
// 新：
Text(completedAt, format: .dateTime.hour().minute())
    .font(.caption2)
    .foregroundStyle(.tertiary)
```

**Step 5: 调整行内边距**

```swift
// iOS/Views/TaskRowView.swift:59
// 旧：.padding(.vertical, 4)
.padding(.vertical, 6)
```

**Step 6: Build 验证**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add iOS/Views/TaskRowView.swift
git commit -m "style(ios): refine TaskRowView spacing and typography hierarchy"
```

---

### Task 2: iOS TaskRowView — 状态指示器与动效

**Files:**
- Modify: `iOS/Views/TaskRowView.swift:23-33` (状态指示器)

**Step 1: 将待办状态从纯色圆改为 SF Symbol 空心圆，完成状态添加 symbolEffect**

```swift
// iOS/Views/TaskRowView.swift:22-33
// 旧：
//     // 状态指示
//     if task.status == .todo {
//         Circle()
//             .fill(task.category.color)
//             .frame(width: 10, height: 10)
//             .accessibilityHidden(true)
//     } else {
//         Image(systemName: "checkmark.circle.fill")
//             .font(.body)
//             .foregroundStyle(Color(.systemGreen))
//             .accessibilityHidden(true)
//     }
// 新：
// 状态指示
if task.status == .todo {
    Image(systemName: "circle")
        .font(.body)
        .foregroundStyle(task.category.color)
        .accessibilityHidden(true)
} else {
    Image(systemName: "checkmark.circle.fill")
        .font(.body)
        .foregroundStyle(Color(.systemGreen))
        .symbolEffect(.bounce, value: task.status == .done)
        .accessibilityHidden(true)
}
```

**Step 2: Build 验证**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add iOS/Views/TaskRowView.swift
git commit -m "style(ios): update status indicators to SF Symbol circle with bounce effect"
```

---

### Task 3: iOS TaskListView — 间距、chevron 旋转与发送按钮动效

**Files:**
- Modify: `iOS/Views/TaskListView.swift:68-72` (已完成 section chevron)
- Modify: `iOS/Views/TaskListView.swift:80` (contentMargins)
- Modify: `iOS/Views/TaskListView.swift:134-142` (发送按钮 transition)
- Modify: `iOS/Views/TaskListView.swift:145` (inputBar padding)

**Step 1: "已完成" section 的 chevron 改为旋转动效，计数颜色调整**

```swift
// iOS/Views/TaskListView.swift:65-73
// 旧：
//     HStack {
//         Text("已完成")
//         Spacer()
//         Text("\(done.count)")
//             .foregroundStyle(.secondary)
//         Image(systemName: isDoneExpanded ? "chevron.up" : "chevron.down")
//             .font(.caption)
//             .foregroundStyle(.secondary)
//     }
// 新：
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
```

**Step 2: 调整列表底部 contentMargins**

```swift
// iOS/Views/TaskListView.swift:80
// 旧：.contentMargins(.bottom, 60)
.contentMargins(.bottom, 70)
```

**Step 3: 给发送按钮添加 transition**

```swift
// iOS/Views/TaskListView.swift:134-142
// 旧：
//     if !newTaskTitle.isEmpty {
//         Button(action: addTask) {
//             Image(systemName: "arrow.up.circle.fill")
//                 .font(.title2)
//                 .foregroundStyle(.tint)
//         }
//         .accessibilityLabel("添加任务")
//         .frame(minWidth: 44, minHeight: 44)
//     }
// 新：
if !newTaskTitle.isEmpty {
    Button(action: addTask) {
        Image(systemName: "arrow.up.circle.fill")
            .font(.title2)
            .foregroundStyle(.tint)
    }
    .accessibilityLabel("添加任务")
    .frame(minWidth: 44, minHeight: 44)
    .transition(.scale.combined(with: .opacity))
}
```

**Step 4: 调整 inputBar 垂直间距**

```swift
// iOS/Views/TaskListView.swift:145
// 旧：.padding(.vertical, 8)
.padding(.vertical, 10)
```

**Step 5: Build 验证**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add iOS/Views/TaskListView.swift
git commit -m "style(ios): add chevron rotation, button transition, and spacing refinements"
```

---

### Task 4: iOS TaskListView — 列表行 transition

**Files:**
- Modify: `iOS/Views/TaskListView.swift:86-107` (taskRows 函数)

**Step 1: 给 ForEach 内的行添加 asymmetric transition**

```swift
// iOS/Views/TaskListView.swift:86-107
// 旧：
//     @ViewBuilder
//     private func taskRows(_ tasks: [TaskItem]) -> some View {
//         ForEach(tasks) { task in
//             iOSTaskRowView(
//                 ...
//             )
//         }
//     }
// 新：在 iOSTaskRowView(...) 闭包末尾、) 之后添加 .transition
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
        },
        onUpdateTitle: { newTitle in
            store.updateTitle(id: task.id, newTitle: newTitle)
        }
    )
    .transition(
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        )
    )
}
```

**Step 2: Build 验证**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add iOS/Views/TaskListView.swift
git commit -m "style(ios): add asymmetric list row transitions"
```

---

### Task 5: macOS TaskRowView — 状态指示器优化

**Files:**
- Modify: `macOS/Views/TaskRowView.swift:144-178` (leadingButton)

**Step 1: 将待办纯色圆改为 SF Symbol 空心圆，完成状态添加 symbolEffect**

```swift
// macOS/Views/TaskRowView.swift:143-178
// 旧的 leadingButton 计算属性
// 新：
@ViewBuilder
private var leadingButton: some View {
    if task.status == .todo {
        Button(action: onToggleCategory) {
            ZStack {
                Circle()
                    .fill(task.category.color.opacity(isHovered ? 0.15 : 0))
                    .frame(width: 24, height: 24)
                    .animation(.easeInOut(duration: 0.1), value: isHovered)

                Image(systemName: "circle")
                    .font(.body)
                    .foregroundStyle(task.category.color)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .help(task.category.label)
    } else {
        Button(action: onCycleStatus) {
            ZStack {
                Circle()
                    .fill(Color(.systemGreen).opacity(isHovered ? 0.15 : 0))
                    .frame(width: 24, height: 24)
                    .animation(.easeInOut(duration: 0.1), value: isHovered)

                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color(.systemGreen))
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, value: task.status == .done)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .help("标记为未完成")
    }
}
```

**Step 2: Build 验证**

Run: `xcodebuild build -scheme GroTask -configuration Debug 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add macOS/Views/TaskRowView.swift
git commit -m "style(macos): update status indicators to SF Symbol circle with bounce effect"
```

---

### Task 6: macOS TaskRowView — 字体层级优化

**Files:**
- Modify: `macOS/Views/TaskRowView.swift:36-39` (已完成标题样式)
- Modify: `macOS/Views/TaskRowView.swift:44-46` (时间戳样式)

**Step 1: 优化已完成标题样式**

```swift
// macOS/Views/TaskRowView.swift:36-40
// 旧：
//     Text(task.title)
//         .font(.body)
//         .foregroundStyle(task.status == .done ? .tertiary : .primary)
//         .strikethrough(task.status == .done, color: Color.secondary.opacity(0.5))
//         .lineLimit(2)
// 新：
Text(task.title)
    .font(.body)
    .foregroundStyle(task.status == .done ? .secondary : .primary)
    .opacity(task.status == .done ? 0.6 : 1)
    .strikethrough(task.status == .done, color: Color.secondary.opacity(0.5))
    .lineLimit(2)
```

**Step 2: 优化时间戳可见度**

```swift
// macOS/Views/TaskRowView.swift:44-46
// 旧：
//     Text(completedAt, format: .dateTime.hour().minute())
//         .font(.caption)
//         .foregroundStyle(.quaternary)
// 新：
Text(completedAt, format: .dateTime.hour().minute())
    .font(.caption)
    .foregroundStyle(.tertiary)
```

**Step 3: Build 验证**

Run: `xcodebuild build -scheme GroTask -configuration Debug 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add macOS/Views/TaskRowView.swift
git commit -m "style(macos): refine completed task typography hierarchy"
```

---

### Task 7: macOS TaskPopoverView — Section header 间距统一与 chevron 旋转

**Files:**
- Modify: `macOS/Views/TaskPopoverView.swift:177` (pinnedSectionHeader horizontal padding)
- Modify: `macOS/Views/TaskPopoverView.swift:200` (doneSectionHeader chevron)
- Modify: `macOS/Views/TaskPopoverView.swift:206` (doneSectionHeader horizontal padding)
- Modify: `macOS/Views/TaskPopoverView.swift:224` (sectionHeader horizontal padding)

**Step 1: Section header padding 统一为 16**

```swift
// macOS/Views/TaskPopoverView.swift — pinnedSectionHeader:177
// 旧：.padding(.horizontal, 18)
.padding(.horizontal, 16)

// macOS/Views/TaskPopoverView.swift — doneSectionHeader:206
// 旧：.padding(.horizontal, 18)
.padding(.horizontal, 16)

// macOS/Views/TaskPopoverView.swift — sectionHeader:224
// 旧：.padding(.horizontal, 18)
.padding(.horizontal, 16)
```

**Step 2: doneSectionHeader chevron 改为旋转动效**

```swift
// macOS/Views/TaskPopoverView.swift:200-202
// 旧：
//     Image(systemName: isDoneExpanded ? "chevron.up" : "chevron.down")
//         .font(.caption2.weight(.medium))
//         .foregroundStyle(.quaternary)
// 新：
Image(systemName: "chevron.down")
    .font(.caption2.weight(.medium))
    .foregroundStyle(.quaternary)
    .rotationEffect(isDoneExpanded ? .degrees(-180) : .zero)
    .animation(.easeInOut(duration: 0.2), value: isDoneExpanded)
```

**Step 3: Build 验证**

Run: `xcodebuild build -scheme GroTask -configuration Debug 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add macOS/Views/TaskPopoverView.swift
git commit -m "style(macos): unify section header padding and add chevron rotation"
```

---

### Task 8: 最终双平台 build 验证

**Step 1: Build macOS**

Run: `xcodebuild build -scheme GroTask -configuration Debug 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 2: Build iOS**

Run: `xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS" 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: 运行测试**

Run: `xcodebuild test -scheme GroTask -destination "platform=macOS" 2>&1 | tail -10`
Expected: All tests pass

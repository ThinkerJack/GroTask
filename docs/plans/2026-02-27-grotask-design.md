# GroTask Design Document

## Overview

GroTask is a macOS menu bar task management app. Click the menu bar icon to show a floating panel for creating, viewing, and completing tasks. Data is stored locally as JSON.

## Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Minimum Target**: macOS 13 (Ventura)
- **Architecture**: MVVM
- **Menu Bar**: `MenuBarExtra` with `.window` style

## Project Structure

```
GroTask/
├── GroTaskApp.swift              # Entry point, MenuBarExtra declaration
├── Models/
│   └── TaskItem.swift            # TaskItem model + TaskStatus enum
├── ViewModels/
│   └── TaskStore.swift           # Data management, JSON read/write
├── Views/
│   ├── TaskPopoverView.swift     # Main panel (list + input field)
│   ├── TaskRowView.swift         # Single task row
│   └── StatusCycleButton.swift   # Status toggle button
└── Assets.xcassets               # App icon resources
```

## Data Model

### TaskStatus

```swift
enum TaskStatus: Int, CaseIterable, Codable {
    case todo = 0        // Not started
    case inProgress = 1  // In progress
    case done = 2        // Completed
}
```

### TaskItem

```swift
struct TaskItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var status: TaskStatus
    let createdAt: Date
    var completedAt: Date?
}
```

### Status Flow

Click status icon to cycle: `todo -> inProgress -> done -> todo`

- Entering `done`: auto-record `completedAt`
- Leaving `done`: clear `completedAt`

## Data Storage

- **Path**: `~/Library/Application Support/GroTask/tasks.json`
- **Format**: JSON array with ISO 8601 dates
- **Write strategy**: Write on every change (low frequency operations)
- **Error handling**: Backup corrupt file as `.bak`, restart with empty array
- **Sort**: Within each group, newest first (by `createdAt`); Done group sorted by `completedAt` descending

## UI Design

### Panel Layout

- **Width**: 320pt fixed
- **Style**: Minimal list (similar to system Reminders)
- **Background**: `NSVisualEffectView` with `.popover` material (frosted glass)
- **Corner radius**: 12pt

```
┌─────────────────────────────┐
│  GroTask          [+]       │  Header: title + add button
├─────────────────────────────┤
│  TO DO                    2 │  Section header (gray, 10pt)
│  ○  Task title              │  Empty circle = todo (gray)
│  ○  Task title              │
│                             │
│  IN PROGRESS              1 │
│  ◎  Task title              │  Dotted circle = in progress (blue, pulse)
│                             │
│  DONE                     1 │
│  ✓  Task title   15:30      │  Filled check = done (green, strikethrough)
├─────────────────────────────┤
│  [ New task... ]      ↵     │  Quick-add input field
└─────────────────────────────┘
```

### Typography

| Element | Size | Weight |
|---------|------|--------|
| Task title | 13pt | regular |
| Section header | 10pt | semibold, uppercased, tracking 0.5 |
| Timestamp | 11pt | regular |
| Count badge | 10pt | medium |

### Color Scheme (Semantic System Colors)

| Status | SF Symbol | Color |
|--------|-----------|-------|
| Todo | `circle` | `Color(.systemGray)` |
| In Progress | `circle.dotted.and.circle` | `Color(.controlAccentColor)` |
| Done | `checkmark.circle.fill` | `Color(.systemGreen)` |

All colors auto-adapt to dark/light mode and accessibility settings.

### Menu Bar Icon

- SF Symbol: `checklist`
- Set as template image (auto dark/light tinting)

### Interactions

- **Left-click** menu bar icon: Toggle panel
- **Right-click** menu bar icon: Show NSMenu (Settings, Quit)
- **Click status icon**: Cycle status with spring animation + symbol magic replace
- **In-progress icon**: Subtle pulse animation
- **Done tasks**: Title gets strikethrough + tertiary color
- **Enter** in input field: Add new task (default: todo)
- **Hover** task row: Show delete button (trash icon)
- **Hover** row background: `Color.primary.opacity(0.06)` rounded rect

### Animations

- Status icon swap: `.contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))`
- In-progress pulse: `.symbolEffect(.pulse, options: .repeating.speed(0.5))`
- Row insertion: `.transition(.move(edge: .top).combined(with: .opacity))`
- Spring timing: `.spring(response: 0.25, dampingFraction: 0.75)`

### Row Dimensions

- Height: ~32pt (6pt vertical padding)
- Horizontal padding: 12pt
- Status icon tap target: 24x24pt
- Hover background corner radius: 6pt

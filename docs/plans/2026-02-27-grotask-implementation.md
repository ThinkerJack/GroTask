# GroTask Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar task management app with SwiftUI that shows a floating panel for managing tasks with three statuses (todo/inProgress/done), stored as local JSON.

**Architecture:** MVVM with SwiftUI MenuBarExtra (.window style). TaskStore manages all data operations and persists to ~/Library/Application Support/GroTask/tasks.json. Views are purely declarative, driven by TaskStore state.

**Tech Stack:** Swift, SwiftUI, macOS 13+, XcodeGen (project generation)

**Design Doc:** `docs/plans/2026-02-27-grotask-design.md`

---

### Task 1: Scaffold Xcode Project

**Files:**
- Create: `project.yml` (XcodeGen spec)
- Create: `GroTask/Info.plist`
- Create: `GroTask/GroTask.entitlements`
- Create: `GroTask/Assets.xcassets/Contents.json`
- Create: `GroTask/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Step 1: Install XcodeGen if needed**

Run: `brew list xcodegen || brew install xcodegen`
Expected: xcodegen available

**Step 2: Create project.yml**

```yaml
name: GroTask
options:
  bundleIdPrefix: com.grotask
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"

targets:
  GroTask:
    type: application
    platform: macOS
    sources:
      - path: GroTask
    settings:
      base:
        INFOPLIST_FILE: GroTask/Info.plist
        CODE_SIGN_ENTITLEMENTS: GroTask/GroTask.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.grotask.app
        PRODUCT_NAME: GroTask
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        COMBINE_HIDPI_IMAGES: true
    info:
      path: GroTask/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: GroTask
        CFBundleDisplayName: GroTask
        CFBundleIdentifier: com.grotask.app
        CFBundleVersion: "1"
        CFBundleShortVersionString: "1.0.0"
        CFBundlePackageType: APPL
        CFBundleExecutable: GroTask
        LSMinimumSystemVersion: "13.0"
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
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/GroTask.app/Contents/MacOS/GroTask"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

**Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

`LSUIElement = true` hides the app from the Dock — menu bar only.

**Step 4: Create entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

**Step 5: Create Assets.xcassets**

`GroTask/Assets.xcassets/Contents.json`:
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`GroTask/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 6: Create placeholder app entry point**

Create `GroTask/GroTaskApp.swift`:
```swift
import SwiftUI

@main
struct GroTaskApp: App {
    var body: some Scene {
        MenuBarExtra("GroTask", systemImage: "checklist") {
            Text("GroTask is loading...")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
```

**Step 7: Create test directory placeholder**

Create `GroTaskTests/GroTaskTests.swift`:
```swift
import XCTest
@testable import GroTask

final class GroTaskTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
```

**Step 8: Generate Xcode project and verify build**

Run: `cd /Users/wuchao/Documents/GitHub/GroTask && xcodegen generate`
Expected: `⚙ Generating plists...` then `Created project at ...`

Run: `xcodebuild -project GroTask.xcodeproj -scheme GroTask -configuration Debug build`
Expected: `BUILD SUCCEEDED`

**Step 9: Commit**

```bash
git init
git add project.yml GroTask/ GroTaskTests/ GroTask.xcodeproj/
git commit -m "feat: scaffold GroTask macOS menu bar app project"
```

---

### Task 2: Data Model — TaskStatus and TaskItem

**Files:**
- Create: `GroTask/Models/TaskItem.swift`
- Create: `GroTaskTests/TaskItemTests.swift`

**Step 1: Write failing tests for TaskStatus**

Create `GroTaskTests/TaskItemTests.swift`:
```swift
import XCTest
@testable import GroTask

final class TaskStatusTests: XCTestCase {

    func testNextCycles() {
        XCTAssertEqual(TaskStatus.todo.next, .inProgress)
        XCTAssertEqual(TaskStatus.inProgress.next, .done)
        XCTAssertEqual(TaskStatus.done.next, .todo)
    }

    func testSymbolName() {
        XCTAssertEqual(TaskStatus.todo.symbolName, "circle")
        XCTAssertEqual(TaskStatus.inProgress.symbolName, "circle.dotted.and.circle")
        XCTAssertEqual(TaskStatus.done.symbolName, "checkmark.circle.fill")
    }

    func testLabel() {
        XCTAssertEqual(TaskStatus.todo.label, "未开始")
        XCTAssertEqual(TaskStatus.inProgress.label, "进行中")
        XCTAssertEqual(TaskStatus.done.label, "已完成")
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in TaskStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(TaskStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }
}

final class TaskItemTests: XCTestCase {

    func testInitDefaults() {
        let task = TaskItem(title: "Test task")
        XCTAssertEqual(task.title, "Test task")
        XCTAssertEqual(task.status, .todo)
        XCTAssertNotNil(task.id)
        XCTAssertNotNil(task.createdAt)
        XCTAssertNil(task.completedAt)
    }

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let task = TaskItem(title: "Code review")
        let data = try encoder.encode(task)
        let decoded = try decoder.decode(TaskItem.self, from: data)

        XCTAssertEqual(decoded.id, task.id)
        XCTAssertEqual(decoded.title, task.title)
        XCTAssertEqual(decoded.status, task.status)
    }

    func testCycleStatusSetsCompletedAt() {
        var task = TaskItem(title: "Finish report")
        XCTAssertEqual(task.status, .todo)
        XCTAssertNil(task.completedAt)

        task.cycleStatus() // todo -> inProgress
        XCTAssertEqual(task.status, .inProgress)
        XCTAssertNil(task.completedAt)

        task.cycleStatus() // inProgress -> done
        XCTAssertEqual(task.status, .done)
        XCTAssertNotNil(task.completedAt)

        task.cycleStatus() // done -> todo
        XCTAssertEqual(task.status, .todo)
        XCTAssertNil(task.completedAt)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project GroTask.xcodeproj -scheme GroTask -destination 'platform=macOS' 2>&1 | tail -20`
Expected: FAIL — `TaskStatus` and `TaskItem` not defined

**Step 3: Implement TaskItem.swift**

Create `GroTask/Models/TaskItem.swift`:
```swift
import SwiftUI

// MARK: - TaskStatus

enum TaskStatus: Int, CaseIterable, Identifiable, Codable {
    case todo = 0
    case inProgress = 1
    case done = 2

    var id: Int { rawValue }

    var next: TaskStatus {
        TaskStatus(rawValue: (rawValue + 1) % 3) ?? .todo
    }

    var symbolName: String {
        switch self {
        case .todo:       return "circle"
        case .inProgress: return "circle.dotted.and.circle"
        case .done:       return "checkmark.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .todo:       return Color(.systemGray)
        case .inProgress: return Color(.controlAccentColor)
        case .done:       return Color(.systemGreen)
        }
    }

    var label: String {
        switch self {
        case .todo:       return "未开始"
        case .inProgress: return "进行中"
        case .done:       return "已完成"
        }
    }
}

// MARK: - TaskItem

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var status: TaskStatus
    let createdAt: Date
    var completedAt: Date?

    init(title: String, status: TaskStatus = .todo) {
        self.id = UUID()
        self.title = title
        self.status = status
        self.createdAt = Date()
        self.completedAt = nil
    }

    mutating func cycleStatus() {
        status = status.next
        if status == .done {
            completedAt = Date()
        } else {
            completedAt = nil
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project GroTask.xcodeproj -scheme GroTask -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add GroTask/Models/TaskItem.swift GroTaskTests/TaskItemTests.swift
git commit -m "feat: add TaskStatus enum and TaskItem model with tests"
```

---

### Task 3: Data Persistence — TaskStore

**Files:**
- Create: `GroTask/ViewModels/TaskStore.swift`
- Create: `GroTaskTests/TaskStoreTests.swift`

**Step 1: Write failing tests for TaskStore**

Create `GroTaskTests/TaskStoreTests.swift`:
```swift
import XCTest
@testable import GroTask

final class TaskStoreTests: XCTestCase {

    var tempDir: URL!
    var store: TaskStore!

    override func setUp() {
        super.setUp()
        // Use a temp directory for each test to avoid cross-contamination
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = TaskStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testAddTask() {
        XCTAssertEqual(store.tasks.count, 0)
        store.addTask(title: "Buy groceries")
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].title, "Buy groceries")
        XCTAssertEqual(store.tasks[0].status, .todo)
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

        store.cycleStatus(id: id) // todo -> inProgress
        XCTAssertEqual(store.tasks[0].status, .inProgress)

        store.cycleStatus(id: id) // inProgress -> done
        XCTAssertEqual(store.tasks[0].status, .done)
        XCTAssertNotNil(store.tasks[0].completedAt)

        store.cycleStatus(id: id) // done -> todo
        XCTAssertEqual(store.tasks[0].status, .todo)
        XCTAssertNil(store.tasks[0].completedAt)
    }

    func testPersistenceRoundTrip() {
        store.addTask(title: "Persist me")
        store.addTask(title: "Me too")

        // Create a new store pointing at the same directory
        let store2 = TaskStore(directory: tempDir)
        XCTAssertEqual(store2.tasks.count, 2)
        XCTAssertEqual(store2.tasks.map(\.title).sorted(), ["Me too", "Persist me"])
    }

    func testGroupedTasks() {
        store.addTask(title: "Todo task")
        store.addTask(title: "In progress task")
        store.addTask(title: "Done task")

        let id1 = store.tasks[1].id // "In progress task"
        store.cycleStatus(id: id1)  // -> inProgress

        let id2 = store.tasks[2].id // "Done task"
        store.cycleStatus(id: id2)  // -> inProgress
        store.cycleStatus(id: id2)  // -> done

        XCTAssertEqual(store.tasks(for: .todo).count, 1)
        XCTAssertEqual(store.tasks(for: .inProgress).count, 1)
        XCTAssertEqual(store.tasks(for: .done).count, 1)
    }

    func testCorruptFileRecovery() throws {
        // Write corrupt JSON
        let filePath = tempDir.appendingPathComponent("tasks.json")
        try "not valid json{{{".write(to: filePath, atomically: true, encoding: .utf8)

        // Should recover gracefully with empty array
        let recoveredStore = TaskStore(directory: tempDir)
        XCTAssertEqual(recoveredStore.tasks.count, 0)

        // Backup file should exist
        let backupPath = tempDir.appendingPathComponent("tasks.json.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath.path))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project GroTask.xcodeproj -scheme GroTask -destination 'platform=macOS' 2>&1 | tail -20`
Expected: FAIL — `TaskStore` not defined

**Step 3: Implement TaskStore**

Create `GroTask/ViewModels/TaskStore.swift`:
```swift
import Foundation
import SwiftUI

@Observable
final class TaskStore {

    private(set) var tasks: [TaskItem] = []
    private let fileURL: URL

    /// Production initializer — uses ~/Library/Application Support/GroTask/
    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("GroTask", isDirectory: true)
        self.init(directory: dir)
    }

    /// Testable initializer — accepts any directory
    init(directory: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.fileURL = directory.appendingPathComponent("tasks.json")
        self.tasks = Self.load(from: fileURL)
    }

    // MARK: - Public API

    func addTask(title: String) {
        let task = TaskItem(title: title)
        tasks.insert(task, at: 0)
        save()
    }

    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func cycleStatus(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].cycleStatus()
        save()
    }

    func tasks(for status: TaskStatus) -> [TaskItem] {
        let filtered = tasks.filter { $0.status == status }
        if status == .done {
            return filtered.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [TaskItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([TaskItem].self, from: data)
        } catch {
            // Corrupt file: backup and start fresh
            print("TaskStore: JSON decode failed, backing up corrupt file: \(error)")
            let backupURL = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: url, to: backupURL)
            return []
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project GroTask.xcodeproj -scheme GroTask -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add GroTask/ViewModels/TaskStore.swift GroTaskTests/TaskStoreTests.swift
git commit -m "feat: add TaskStore with JSON persistence and tests"
```

---

### Task 4: StatusCycleButton View

**Files:**
- Create: `GroTask/Views/StatusCycleButton.swift`

**Step 1: Implement StatusCycleButton**

Create `GroTask/Views/StatusCycleButton.swift`:
```swift
import SwiftUI

struct StatusCycleButton: View {
    let status: TaskStatus
    let onCycle: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onCycle) {
            ZStack {
                Circle()
                    .fill(status.accentColor.opacity(isHovered ? 0.15 : 0))
                    .frame(width: 24, height: 24)
                    .animation(.easeInOut(duration: 0.1), value: isHovered)

                Image(systemName: status.symbolName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(status.accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(
                        .symbolEffect(.replace.magic(fallback: .replace))
                    )
                    .symbolEffect(
                        .pulse,
                        options: .repeating.speed(0.5),
                        isActive: status == .inProgress && !isHovered
                    )
            }
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(status.label)
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project GroTask.xcodeproj -scheme GroTask -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add GroTask/Views/StatusCycleButton.swift
git commit -m "feat: add StatusCycleButton with animations"
```

---

### Task 5: TaskRowView

**Files:**
- Create: `GroTask/Views/TaskRowView.swift`

**Step 1: Implement TaskRowView**

Create `GroTask/Views/TaskRowView.swift`:
```swift
import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let onCycleStatus: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            StatusCycleButton(status: task.status, onCycle: onCycleStatus)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 13))
                    .foregroundStyle(task.status == .done ? .tertiary : .primary)
                    .strikethrough(task.status == .done, color: .tertiary)
                    .lineLimit(2)

                if task.status == .done, let completedAt = task.completedAt {
                    Text(completedAt, format: .dateTime.hour().minute())
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .help("删除任务")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .padding(.horizontal, 6)
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project GroTask.xcodeproj -scheme GroTask -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add GroTask/Views/TaskRowView.swift
git commit -m "feat: add TaskRowView with hover and delete"
```

---

### Task 6: Main Panel — TaskPopoverView

**Files:**
- Create: `GroTask/Views/TaskPopoverView.swift`
- Modify: `GroTask/GroTaskApp.swift`

**Step 1: Implement TaskPopoverView**

Create `GroTask/Views/TaskPopoverView.swift`:
```swift
import SwiftUI

struct TaskPopoverView: View {
    @State var store: TaskStore
    @State private var newTaskTitle = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GroTask")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    isInputFocused = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("添加新任务")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

            // Task list
            if store.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("暂无任务")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(TaskStatus.allCases) { status in
                            let tasksForStatus = store.tasks(for: status)
                            if !tasksForStatus.isEmpty {
                                sectionHeader(status: status, count: tasksForStatus.count)

                                ForEach(tasksForStatus) { task in
                                    TaskRowView(
                                        task: task,
                                        onCycleStatus: {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                store.cycleStatus(id: task.id)
                                            }
                                        },
                                        onDelete: {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                store.deleteTask(id: task.id)
                                            }
                                        }
                                    )
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)
                                        )
                                    )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider().opacity(0.5)

            // Quick-add input
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                TextField("新任务...", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isInputFocused)
                    .onSubmit {
                        addTask()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 320)
    }

    // MARK: - Subviews

    private func sectionHeader(status: TaskStatus, count: Int) -> some View {
        HStack {
            Text(status.label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            Spacer()

            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Actions

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            store.addTask(title: trimmed)
        }
        newTaskTitle = ""
    }
}
```

**Step 2: Wire up GroTaskApp.swift**

Replace `GroTask/GroTaskApp.swift` with:
```swift
import SwiftUI

@main
struct GroTaskApp: App {
    @State private var store = TaskStore()

    var body: some Scene {
        MenuBarExtra("GroTask", systemImage: "checklist") {
            TaskPopoverView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
```

**Step 3: Build to verify compilation**

Run: `xcodebuild -project GroTask.xcodeproj -scheme GroTask -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add GroTask/Views/TaskPopoverView.swift GroTask/GroTaskApp.swift
git commit -m "feat: add main panel view and wire up MenuBarExtra"
```

---

### Task 7: Run Full Tests and Manual Verification

**Step 1: Run all unit tests**

Run: `xcodebuild test -project GroTask.xcodeproj -scheme GroTask -destination 'platform=macOS' 2>&1 | tail -30`
Expected: All tests PASS

**Step 2: Run the app for manual verification**

Run: `xcodebuild -project GroTask.xcodeproj -scheme GroTask -configuration Debug build 2>&1 | tail -5`
Then: `open /Users/wuchao/Documents/GitHub/GroTask/build/Build/Products/Debug/GroTask.app` (path may vary)

Manual checklist:
- [ ] Menu bar shows checklist icon
- [ ] Clicking icon opens floating panel
- [ ] Can type task title and press Enter to add
- [ ] Task appears in "未开始" section
- [ ] Clicking circle icon cycles: gray circle -> blue dotted -> green checkmark
- [ ] Done tasks show strikethrough + completion time
- [ ] Hover on task row shows delete button
- [ ] Clicking delete removes the task
- [ ] Quit and reopen: tasks persist

**Step 3: Commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address issues found during manual verification"
```

---

### Task 8: Final Polish — Right-Click Menu and Empty State

**Files:**
- Modify: `GroTask/GroTaskApp.swift` (add right-click quit option via CommandGroup)

**Step 1: Add keyboard shortcut for quit**

The `MenuBarExtra` with `.window` style doesn't natively support right-click menus. Instead, add a subtle "退出" option in the panel footer or use `CommandGroup`:

Modify `GroTask/GroTaskApp.swift`:
```swift
import SwiftUI

@main
struct GroTaskApp: App {
    @State private var store = TaskStore()

    var body: some Scene {
        MenuBarExtra("GroTask", systemImage: "checklist") {
            TaskPopoverView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
```

Add a quit button to the bottom of `TaskPopoverView` — add after the quick-add input section, before the closing `}` of the outer VStack:

In `TaskPopoverView.swift`, add right before the final `.frame(width: 320)`:
```swift
            // Footer with quit
            HStack {
                Spacer()
                Button("退出 GroTask") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
```

**Step 2: Build and verify**

Run: `xcodebuild -project GroTask.xcodeproj -scheme GroTask -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: add quit button to panel footer"
```

---

## Summary

| Task | Description | Estimated Steps |
|------|-------------|-----------------|
| 1 | Scaffold Xcode project | 9 steps |
| 2 | Data model (TaskStatus + TaskItem) | 5 steps (TDD) |
| 3 | TaskStore with JSON persistence | 5 steps (TDD) |
| 4 | StatusCycleButton view | 3 steps |
| 5 | TaskRowView | 3 steps |
| 6 | TaskPopoverView + App wiring | 4 steps |
| 7 | Full test run + manual verification | 3 steps |
| 8 | Polish (quit button) | 3 steps |

Total: **8 tasks, ~35 steps**

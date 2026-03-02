import XCTest
@testable import GroTask

final class TaskStoreTests: XCTestCase {

    var tempDir: URL!
    var store: TaskStore!

    override func setUp() {
        super.setUp()
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
        // addTask prepends, so tasks[1] is "Done task"
        store.cycleStatus(id: store.tasks[1].id)

        XCTAssertEqual(store.doneTasks.count, 1)
        XCTAssertEqual(store.doneTasks[0].title, "Done task")
    }

    func testPinnedDoneTaskNotInPinned() {
        store.addTask(title: "Was pinned")
        let id = store.tasks[0].id
        store.togglePin(id: id)
        store.cycleStatus(id: id)

        // Done tasks should not appear in pinnedTasks
        XCTAssertEqual(store.pinnedTasks.count, 0)
        XCTAssertEqual(store.doneTasks.count, 1)
    }

    func testPersistenceRoundTrip() {
        store.addTask(title: "Persist me", category: .life)
        store.addTask(title: "Me too")

        let store2 = TaskStore(directory: tempDir)
        XCTAssertEqual(store2.tasks.count, 2)
        XCTAssertEqual(store2.tasks.map(\.title).sorted(), ["Me too", "Persist me"])
    }

    func testCorruptFileRecovery() throws {
        let filePath = tempDir.appendingPathComponent("tasks.json")
        try "not valid json{{{".write(to: filePath, atomically: true, encoding: .utf8)

        let recoveredStore = TaskStore(directory: tempDir)
        XCTAssertEqual(recoveredStore.tasks.count, 0)

        let backupPath = tempDir.appendingPathComponent("tasks.json.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath.path))
    }
}

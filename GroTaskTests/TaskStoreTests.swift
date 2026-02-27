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

        store.cycleStatus(id: id)
        XCTAssertEqual(store.tasks[0].status, .inProgress)

        store.cycleStatus(id: id)
        XCTAssertEqual(store.tasks[0].status, .done)
        XCTAssertNotNil(store.tasks[0].completedAt)

        store.cycleStatus(id: id)
        XCTAssertEqual(store.tasks[0].status, .todo)
        XCTAssertNil(store.tasks[0].completedAt)
    }

    func testPersistenceRoundTrip() {
        store.addTask(title: "Persist me")
        store.addTask(title: "Me too")

        let store2 = TaskStore(directory: tempDir)
        XCTAssertEqual(store2.tasks.count, 2)
        XCTAssertEqual(store2.tasks.map(\.title).sorted(), ["Me too", "Persist me"])
    }

    func testGroupedTasks() {
        store.addTask(title: "Todo task")
        store.addTask(title: "In progress task")
        store.addTask(title: "Done task")

        let id1 = store.tasks[1].id
        store.cycleStatus(id: id1)

        let id2 = store.tasks[2].id
        store.cycleStatus(id: id2)
        store.cycleStatus(id: id2)

        XCTAssertEqual(store.tasks(for: .todo).count, 1)
        XCTAssertEqual(store.tasks(for: .inProgress).count, 1)
        XCTAssertEqual(store.tasks(for: .done).count, 1)
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

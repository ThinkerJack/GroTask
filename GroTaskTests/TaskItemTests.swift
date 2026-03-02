import XCTest
@testable import GroTask

final class TaskCategoryTests: XCTestCase {

    func testNextToggles() {
        XCTAssertEqual(TaskCategory.work.next, .life)
        XCTAssertEqual(TaskCategory.life.next, .work)
    }

    func testLabel() {
        XCTAssertEqual(TaskCategory.work.label, "工作")
        XCTAssertEqual(TaskCategory.life.label, "生活")
    }
}

final class TaskStatusTests: XCTestCase {

    func testNextToggles() {
        XCTAssertEqual(TaskStatus.todo.next, .done)
        XCTAssertEqual(TaskStatus.done.next, .todo)
    }

    func testLabel() {
        XCTAssertEqual(TaskStatus.todo.label, "未开始")
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
        XCTAssertEqual(task.category, .work)
        XCTAssertFalse(task.isPinned)
        XCTAssertNotNil(task.id)
        XCTAssertNotNil(task.createdAt)
        XCTAssertNil(task.completedAt)
    }

    func testInitWithCategory() {
        let task = TaskItem(title: "Groceries", category: .life)
        XCTAssertEqual(task.category, .life)
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
        XCTAssertEqual(decoded.category, task.category)
        XCTAssertEqual(decoded.isPinned, task.isPinned)
    }

    func testCycleStatusSetsCompletedAt() {
        var task = TaskItem(title: "Finish report")
        XCTAssertEqual(task.status, .todo)
        XCTAssertNil(task.completedAt)

        task.cycleStatus() // todo -> done
        XCTAssertEqual(task.status, .done)
        XCTAssertNotNil(task.completedAt)

        task.cycleStatus() // done -> todo
        XCTAssertEqual(task.status, .todo)
        XCTAssertNil(task.completedAt)
    }
}

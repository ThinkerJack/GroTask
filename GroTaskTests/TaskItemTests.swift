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

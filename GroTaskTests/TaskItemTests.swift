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
        XCTAssertEqual(task.timeScope, .anytime)
        XCTAssertFalse(task.isPinned)
        XCTAssertNotNil(task.id)
        XCTAssertNotNil(task.createdAt)
        XCTAssertNil(task.completedAt)
    }

    func testInitWithTimeScope() {
        let task = TaskItem(title: "Quick task", timeScope: .quick)
        XCTAssertEqual(task.timeScope, .quick)
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
        XCTAssertEqual(decoded.timeScope, task.timeScope)
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

final class TaskTimeScopeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(TaskTimeScope.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(TaskTimeScope.quick.rawValue, 0)
        XCTAssertEqual(TaskTimeScope.today.rawValue, 1)
        XCTAssertEqual(TaskTimeScope.anytime.rawValue, 2)
        XCTAssertEqual(TaskTimeScope.someday.rawValue, 3)
    }

    func testLabels() {
        XCTAssertEqual(TaskTimeScope.quick.label, "快速")
        XCTAssertEqual(TaskTimeScope.today.label, "今天")
        XCTAssertEqual(TaskTimeScope.anytime.label, "随时")
        XCTAssertEqual(TaskTimeScope.someday.label, "将来")
    }

    func testSymbolNames() {
        XCTAssertFalse(TaskTimeScope.quick.symbolName.isEmpty)
        XCTAssertFalse(TaskTimeScope.today.symbolName.isEmpty)
        XCTAssertFalse(TaskTimeScope.anytime.symbolName.isEmpty)
        XCTAssertFalse(TaskTimeScope.someday.symbolName.isEmpty)
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for scope in TaskTimeScope.allCases {
            let data = try encoder.encode(scope)
            let decoded = try decoder.decode(TaskTimeScope.self, from: data)
            XCTAssertEqual(decoded, scope)
        }
    }
}

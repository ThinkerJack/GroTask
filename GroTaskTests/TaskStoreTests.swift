import XCTest
import CoreData
@testable import GroTask

final class TaskStoreTests: XCTestCase {

    var store: TaskStore!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        store = TaskStore(context: context)
    }

    override func tearDown() {
        store = nil
        context = nil
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
        store.cycleStatus(id: store.tasks[1].id)

        XCTAssertEqual(store.doneTasks.count, 1)
        XCTAssertEqual(store.doneTasks[0].title, "Done task")
    }

    func testPinnedDoneTaskNotInPinned() {
        store.addTask(title: "Was pinned")
        let id = store.tasks[0].id
        store.togglePin(id: id)
        store.cycleStatus(id: id)

        XCTAssertEqual(store.pinnedTasks.count, 0)
        XCTAssertEqual(store.doneTasks.count, 1)
    }

    func testAddTaskWithTimeScope() {
        store.addTask(title: "Quick task", category: .work, timeScope: .quick)
        XCTAssertEqual(store.tasks[0].timeScope, .quick)
    }

    func testAddTaskDefaultTimeScope() {
        store.addTask(title: "Default scope")
        XCTAssertEqual(store.tasks[0].timeScope, .anytime)
    }

    func testSetTimeScope() {
        store.addTask(title: "Change scope")
        let id = store.tasks[0].id
        XCTAssertEqual(store.tasks[0].timeScope, .anytime)

        store.setTimeScope(id: id, scope: .today)
        XCTAssertEqual(store.tasks[0].timeScope, .today)
    }

    func testTasksForTimeScope() {
        store.addTask(title: "Quick one", category: .work, timeScope: .quick)
        store.addTask(title: "Today one", category: .work, timeScope: .today)
        store.addTask(title: "Anytime one", category: .work, timeScope: .anytime)
        store.addTask(title: "Someday one", category: .work, timeScope: .someday)

        XCTAssertEqual(store.tasks(for: .quick).count, 1)
        XCTAssertEqual(store.tasks(for: .today).count, 1)
        XCTAssertEqual(store.tasks(for: .anytime).count, 1)
        XCTAssertEqual(store.tasks(for: .someday).count, 1)
    }

    func testTasksForTimeScopeExcludesDone() {
        store.addTask(title: "Done quick", category: .work, timeScope: .quick)
        store.cycleStatus(id: store.tasks[0].id)

        XCTAssertEqual(store.tasks(for: .quick).count, 0)
    }

    func testTasksForTimeScopeExcludesPinned() {
        store.addTask(title: "Pinned quick", category: .work, timeScope: .quick)
        store.togglePin(id: store.tasks[0].id)

        XCTAssertEqual(store.tasks(for: .quick).count, 0)
    }
}

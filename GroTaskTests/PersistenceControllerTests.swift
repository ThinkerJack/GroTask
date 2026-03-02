import XCTest
import CoreData
@testable import GroTask

final class PersistenceControllerTests: XCTestCase {

    func testInMemoryControllerCreatesContext() {
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.container.viewContext)
    }

    func testInMemoryControllerCanSaveAndFetch() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let entity = TaskItemEntity(context: context)
        entity.id = UUID()
        entity.title = "Test task"
        entity.statusRaw = 0
        entity.categoryRaw = 0
        entity.isPinned = false
        entity.createdAt = Date()

        try context.save()

        let request = NSFetchRequest<TaskItemEntity>(entityName: "TaskItemEntity")
        let results = try context.fetch(request)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Test task")
    }
}

import XCTest
import CoreData
@testable import GroTask

final class MigrationHelperTests: XCTestCase {

    var context: NSManagedObjectContext!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        let controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testMigrateFromJSON() throws {
        // Create a JSON file with tasks
        let tasks = [
            TaskItem(title: "Task 1", category: .work),
            TaskItem(title: "Task 2", category: .life)
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(tasks)
        let jsonURL = tempDir.appendingPathComponent("tasks.json")
        try data.write(to: jsonURL)

        let migrated = MigrationHelper.migrateIfNeeded(jsonDirectory: tempDir, context: context)
        XCTAssertTrue(migrated)

        // Verify entities in Core Data
        let request = NSFetchRequest<TaskItemEntity>(entityName: "TaskItemEntity")
        let entities = try context.fetch(request)
        XCTAssertEqual(entities.count, 2)

        // Verify old file renamed
        XCTAssertFalse(FileManager.default.fileExists(atPath: jsonURL.path))
        let migratedURL = tempDir.appendingPathComponent("tasks.json.migrated")
        XCTAssertTrue(FileManager.default.fileExists(atPath: migratedURL.path))
    }

    func testNoMigrationWhenNoJSON() {
        let migrated = MigrationHelper.migrateIfNeeded(jsonDirectory: tempDir, context: context)
        XCTAssertFalse(migrated)
    }

    func testNoMigrationWhenAlreadyMigrated() throws {
        // Create .migrated file (already migrated)
        let migratedURL = tempDir.appendingPathComponent("tasks.json.migrated")
        try "done".write(to: migratedURL, atomically: true, encoding: .utf8)

        let migrated = MigrationHelper.migrateIfNeeded(jsonDirectory: tempDir, context: context)
        XCTAssertFalse(migrated)
    }
}

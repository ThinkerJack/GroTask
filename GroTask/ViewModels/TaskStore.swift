import Foundation
import SwiftUI

@Observable
final class TaskStore {

    private(set) var tasks: [TaskItem] = []
    private let fileURL: URL

    convenience init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("GroTask", isDirectory: true)
        self.init(directory: dir)
    }

    init(directory: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.fileURL = directory.appendingPathComponent("tasks.json")
        self.tasks = Self.load(from: fileURL)
    }

    // MARK: - CRUD

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

    // MARK: - Filtered / Grouped

    func tasks(for status: TaskStatus) -> [TaskItem] {
        let filtered = tasks.filter { $0.status == status }
        if status == .done {
            return filtered.sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
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
            print("TaskStore: JSON decode failed, backing up corrupt file: \(error)")
            let backupURL = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: url, to: backupURL)
            return []
        }
    }
}

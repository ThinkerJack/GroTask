import SwiftUI

// MARK: - TaskCategory

enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case work
    case life

    var id: String { rawValue }

    var next: TaskCategory {
        self == .work ? .life : .work
    }

    var color: Color {
        switch self {
        case .work: return Color(.systemBlue)
        case .life: return Color(.systemOrange)
        }
    }

    var label: String {
        switch self {
        case .work: return "工作"
        case .life: return "生活"
        }
    }

    var symbolName: String {
        switch self {
        case .work: return "briefcase.fill"
        case .life: return "leaf.fill"
        }
    }
}

// MARK: - TaskStatus

enum TaskStatus: Int, CaseIterable, Identifiable, Codable {
    case todo = 0
    case done = 2

    var id: Int { rawValue }

    var next: TaskStatus {
        self == .todo ? .done : .todo
    }

    var label: String {
        switch self {
        case .todo: return "未开始"
        case .done: return "已完成"
        }
    }
}

// MARK: - TaskItem

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var status: TaskStatus
    var category: TaskCategory
    var isPinned: Bool
    let createdAt: Date
    var completedAt: Date?

    init(title: String, category: TaskCategory = .work, status: TaskStatus = .todo) {
        self.id = UUID()
        self.title = title
        self.status = status
        self.category = category
        self.isPinned = false
        self.createdAt = Date()
        self.completedAt = nil
    }

    init(id: UUID, title: String, status: TaskStatus, category: TaskCategory,
         isPinned: Bool, createdAt: Date, completedAt: Date?) {
        self.id = id
        self.title = title
        self.status = status
        self.category = category
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.completedAt = completedAt
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

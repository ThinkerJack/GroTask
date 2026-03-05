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

// MARK: - TaskTimeScope

enum TaskTimeScope: Int, CaseIterable, Identifiable, Codable {
    case quick   = 0
    case today   = 1
    case anytime = 2
    case someday = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .quick:   return "快速"
        case .today:   return "今天"
        case .anytime: return "随时"
        case .someday: return "将来"
        }
    }

    var symbolName: String {
        switch self {
        case .quick:   return "bolt.fill"
        case .today:   return "sun.max.fill"
        case .anytime: return "hand.thumbsup.fill"
        case .someday: return "cloud.fill"
        }
    }

    var color: Color {
        switch self {
        case .quick:   return Color(.systemYellow)
        case .today:   return Color(.systemRed)
        case .anytime: return Color(.systemGreen)
        case .someday: return Color(.systemGray)
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
    var timeScope: TaskTimeScope
    let createdAt: Date
    var completedAt: Date?

    init(title: String, category: TaskCategory = .work, timeScope: TaskTimeScope = .anytime, status: TaskStatus = .todo) {
        self.id = UUID()
        self.title = title
        self.status = status
        self.category = category
        self.isPinned = false
        self.timeScope = timeScope
        self.createdAt = Date()
        self.completedAt = nil
    }

    init(id: UUID, title: String, status: TaskStatus, category: TaskCategory,
         isPinned: Bool, timeScope: TaskTimeScope, createdAt: Date, completedAt: Date?) {
        self.id = id
        self.title = title
        self.status = status
        self.category = category
        self.isPinned = isPinned
        self.timeScope = timeScope
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

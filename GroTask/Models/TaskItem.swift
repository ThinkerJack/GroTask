import SwiftUI

// MARK: - TaskStatus

enum TaskStatus: Int, CaseIterable, Identifiable, Codable {
    case todo = 0
    case inProgress = 1
    case done = 2

    var id: Int { rawValue }

    var next: TaskStatus {
        TaskStatus(rawValue: (rawValue + 1) % 3) ?? .todo
    }

    var symbolName: String {
        switch self {
        case .todo:       return "circle"
        case .inProgress: return "circle.dotted.and.circle"
        case .done:       return "checkmark.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .todo:       return Color(.systemGray)
        case .inProgress: return Color(.controlAccentColor)
        case .done:       return Color(.systemGreen)
        }
    }

    var label: String {
        switch self {
        case .todo:       return "未开始"
        case .inProgress: return "进行中"
        case .done:       return "已完成"
        }
    }
}

// MARK: - TaskItem

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var status: TaskStatus
    let createdAt: Date
    var completedAt: Date?

    init(title: String, status: TaskStatus = .todo) {
        self.id = UUID()
        self.title = title
        self.status = status
        self.createdAt = Date()
        self.completedAt = nil
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

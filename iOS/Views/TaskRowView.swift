import SwiftUI

struct iOSTaskRowView: View {
    let task: TaskItem
    let onCycleStatus: () -> Void
    let onDelete: () -> Void
    let onToggleCategory: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 状态指示
            if task.status == .todo {
                Circle()
                    .fill(task.category.color)
                    .frame(width: 10, height: 10)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }

            // 标题
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.status == .done ? .tertiary : .primary)
                    .strikethrough(task.status == .done)
                    .lineLimit(2)

                if task.status == .done, let completedAt = task.completedAt {
                    Text(completedAt, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                onCycleStatus()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .contextMenu {
            if task.status == .todo {
                Button {
                    withAnimation { onTogglePin() }
                } label: {
                    Label(
                        task.isPinned ? "取消置顶" : "置顶到今天",
                        systemImage: task.isPinned ? "pin.slash" : "pin"
                    )
                }

                Button {
                    withAnimation { onToggleCategory() }
                } label: {
                    Label(
                        "切换为\(task.category.next.label)",
                        systemImage: "circle.fill"
                    )
                }
            }

            Button(role: .destructive, action: onDelete) {
                Label("删除任务", systemImage: "trash")
            }
        }
    }
}

import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let onCycleStatus: () -> Void
    let onDelete: () -> Void
    let onToggleCategory: () -> Void
    let onTogglePin: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            leadingButton

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 13))
                    .foregroundStyle(task.status == .done ? .tertiary : .primary)
                    .strikethrough(task.status == .done, color: Color.secondary.opacity(0.5))
                    .lineLimit(2)

                if task.status == .done, let completedAt = task.completedAt {
                    Text(completedAt, format: .dateTime.hour().minute())
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .help("删除任务")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if task.status == .todo {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    onCycleStatus()
                }
            }
        }
        .contextMenu {
            if task.status == .todo {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        onTogglePin()
                    }
                } label: {
                    Label(
                        task.isPinned ? "取消置顶" : "置顶到今天",
                        systemImage: task.isPinned ? "pin.slash" : "pin"
                    )
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        onToggleCategory()
                    }
                } label: {
                    Label(
                        "切换为\(task.category.next.label)",
                        systemImage: "circle.fill"
                    )
                }
            }

            Button(role: .destructive) {
                withAnimation(.easeOut(duration: 0.2)) {
                    onDelete()
                }
            } label: {
                Label("删除任务", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .padding(.horizontal, 6)
        .id("\(task.id)-\(task.isPinned)-\(task.category)")
    }

    // MARK: - Leading Button

    @ViewBuilder
    private var leadingButton: some View {
        if task.status == .todo {
            Button(action: onToggleCategory) {
                ZStack {
                    Circle()
                        .fill(task.category.color.opacity(isHovered ? 0.15 : 0))
                        .frame(width: 24, height: 24)
                        .animation(.easeInOut(duration: 0.1), value: isHovered)

                    Circle()
                        .fill(task.category.color)
                        .frame(width: 8, height: 8)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .help(task.category.label)
        } else {
            Button(action: onCycleStatus) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGreen).opacity(isHovered ? 0.15 : 0))
                        .frame(width: 24, height: 24)
                        .animation(.easeInOut(duration: 0.1), value: isHovered)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(.systemGreen))
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .help("标记为未完成")
        }
    }

    private var rowBackground: Color {
        if isHovered {
            return Color.primary.opacity(0.06)
        }
        if task.status == .done {
            return Color(.systemGreen).opacity(0.06)
        }
        return Color.clear
    }
}

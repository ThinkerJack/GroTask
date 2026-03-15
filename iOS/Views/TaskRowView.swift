import SwiftUI

struct iOSTaskRowView: View {
    let task: TaskItem
    let onCycleStatus: () -> Void
    let onDelete: () -> Void
    let onToggleCategory: () -> Void
    let onTogglePin: () -> Void
    let onUpdateTitle: (String) -> Void
    let onSetTimeScope: (TaskTimeScope) -> Void
    @State private var isEditing = false
    @State private var editingTitle = ""
    @FocusState private var isEditFocused: Bool

    var body: some View {
        Button {
            if isEditing { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                onCycleStatus()
            }
        } label: {
            HStack(spacing: 10) {
                if task.status == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color(.systemGreen))
                        .symbolEffect(.bounce, value: task.status == .done)
                        .accessibilityHidden(true)
                }

                // 标题
                VStack(alignment: .leading, spacing: 3) {
                    if isEditing {
                        TextField("任务标题", text: $editingTitle)
                            .font(.body)
                            .focused($isEditFocused)
                            .onSubmit { commitEdit() }
                    } else {
                        Text(task.title)
                            .font(.body)
                            .foregroundStyle(task.status == .done ? .secondary : .primary)
                            .opacity(task.status == .done ? 0.6 : 1)
                            .strikethrough(task.status == .done)
                            .lineLimit(2)
                    }

                    if task.status == .done, let completedAt = task.completedAt {
                        Text(completedTimeText(completedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if task.status == .todo {
                    Circle()
                        .fill(task.category.color)
                        .frame(width: 7, height: 7)
                        .opacity(0.5)

                    if task.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.title)
        .accessibilityValue("\(task.category.label)，\(task.timeScope.label)，\(task.status.label)")
        .accessibilityHint(task.status == .todo ? "双击标记为已完成" : "双击标记为未完成")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .contextMenu {
            if task.status == .todo {
                Button {
                    startEditing()
                } label: {
                    Label("编辑任务", systemImage: "pencil")
                }

                Button {
                    withAnimation { onToggleCategory() }
                } label: {
                    Label(
                        "切换为\(task.category.next.label)",
                        systemImage: "circle.fill"
                    )
                }

                Menu {
                    ForEach(TaskTimeScope.allCases) { scope in
                        if scope != task.timeScope {
                            Button {
                                withAnimation { onSetTimeScope(scope) }
                            } label: {
                                Label(scope.label, systemImage: scope.symbolName)
                            }
                        }
                    }
                } label: {
                    Label("时间视角", systemImage: "clock")
                }
            }

            Button(role: .destructive, action: onDelete) {
                Label("删除任务", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func completedTimeText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            return formatter.string(from: date)
        }
    }

    // MARK: - Editing

    private func startEditing() {
        editingTitle = task.title
        isEditing = true
        isEditFocused = true
    }

    private func commitEdit() {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != task.title {
            onUpdateTitle(trimmed)
        }
        isEditing = false
    }
}

import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let onCycleStatus: () -> Void
    let onDelete: () -> Void
    let onToggleCategory: () -> Void
    let onTogglePin: () -> Void
    let onUpdateTitle: (String) -> Void
    let onSetTimeScope: (TaskTimeScope) -> Void
    @State private var isHovered = false
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
            HStack(spacing: 8) {
                if task.status == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color(.systemGreen))
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 1) {
                    if isEditing {
                        TextField("任务标题", text: $editingTitle)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .focused($isEditFocused)
                            .onSubmit { commitEdit() }
                            .onExitCommand { cancelEdit() }
                    } else {
                        Text(task.title)
                            .font(.body)
                            .foregroundStyle(task.status == .done ? .secondary : .primary)
                            .opacity(task.status == .done ? 0.6 : 1)
                            .strikethrough(task.status == .done, color: Color.secondary.opacity(0.5))
                            .lineLimit(2)
                    }

                    if task.status == .done, let completedAt = task.completedAt {
                        Text(completedTimeText(completedAt))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if task.status == .todo {
                    Circle()
                        .fill(task.category.color)
                        .frame(width: 7, height: 7)
                        .opacity(isHovered ? 0.7 : 0.5)
                        .animation(.easeInOut(duration: 0.1), value: isHovered)

                    if task.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if isHovered && !isEditing {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .help("删除任务")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(rowBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.title)
        .accessibilityValue("\(task.category.label)，\(task.timeScope.label)，\(task.status.label)")
        .contextMenu {
            if task.status == .todo {
                Button {
                    startEditing()
                } label: {
                    Label("编辑任务", systemImage: "pencil")
                }

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

                Menu {
                    ForEach(TaskTimeScope.allCases) { scope in
                        if scope != task.timeScope {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    onSetTimeScope(scope)
                                }
                            } label: {
                                Label(scope.label, systemImage: scope.symbolName)
                            }
                        }
                    }
                } label: {
                    Label("时间视角", systemImage: "clock")
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
        .id("\(task.id)-\(task.status)-\(task.isPinned)-\(task.category)-\(task.timeScope)")
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

    private func cancelEdit() {
        isEditing = false
    }

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

    private var rowBackground: Color {
        if isHovered {
            return Color.primary.opacity(0.08)
        }
        if task.status == .done {
            return Color(.systemGreen).opacity(0.05)
        }
        return Color.clear
    }
}

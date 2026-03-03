import SwiftUI

struct TaskPopoverView: View {
    var store: TaskStore
    @State private var newTaskTitle = ""
    @State private var newTaskCategory: TaskCategory = .work
    @State private var newTaskTimeScope: TaskTimeScope = .anytime
    @State private var isDoneExpanded = false
    @State private var collapsedScopes: Set<TaskTimeScope> = [.someday]
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GroTask")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    isInputFocused = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("添加新任务")
                .accessibilityLabel("添加新任务")
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)

            Divider().opacity(0.5)

            // Task list
            if store.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundStyle(.quaternary)
                    Text("暂无任务")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 置顶区
                        let pinned = store.pinnedTasks
                        if !pinned.isEmpty {
                            pinnedSectionHeader(count: pinned.count)
                            taskRows(pinned)
                        }

                        // 按时间视角分组
                        ForEach(TaskTimeScope.allCases) { scope in
                            let scopeTasks = store.tasks(for: scope)
                            if !scopeTasks.isEmpty {
                                timeScopeSectionHeader(scope: scope, count: scopeTasks.count)
                                if !collapsedScopes.contains(scope) {
                                    taskRows(scopeTasks)
                                }
                            }
                        }

                        // 已完成区
                        let done = store.doneTasks
                        if !done.isEmpty {
                            doneSectionHeader(count: done.count)
                            if isDoneExpanded {
                                taskRows(done)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider().opacity(0.5)

            // Quick-add input with category selector
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        newTaskCategory = newTaskCategory.next
                    }
                } label: {
                    Circle()
                        .fill(newTaskCategory.color)
                        .frame(width: 8, height: 8)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help(newTaskCategory.label)
                .accessibilityLabel("类别：\(newTaskCategory.label)")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        let allCases = TaskTimeScope.allCases
                        let currentIndex = allCases.firstIndex(of: newTaskTimeScope) ?? 0
                        newTaskTimeScope = allCases[(currentIndex + 1) % allCases.count]
                    }
                } label: {
                    Image(systemName: newTaskTimeScope.symbolName)
                        .font(.caption)
                        .foregroundStyle(newTaskTimeScope.color)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help(newTaskTimeScope.label)
                .accessibilityLabel("时间视角：\(newTaskTimeScope.label)")

                TextField("新任务...", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isInputFocused)
                    .onSubmit {
                        addTask()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Footer with quit
            HStack {
                Spacer()
                Button("退出 GroTask") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .frame(width: 320)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func taskRows(_ tasks: [TaskItem]) -> some View {
        ForEach(tasks) { task in
            TaskRowView(
                task: task,
                onCycleStatus: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        store.cycleStatus(id: task.id)
                    }
                },
                onDelete: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        store.deleteTask(id: task.id)
                    }
                },
                onToggleCategory: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.toggleCategory(id: task.id)
                    }
                },
                onTogglePin: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        store.togglePin(id: task.id)
                    }
                },
                onUpdateTitle: { newTitle in
                    store.updateTitle(id: task.id, newTitle: newTitle)
                }
            )
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                )
            )
        }
    }

    private func pinnedSectionHeader(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "pin.fill")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("今天".uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            Spacer()

            Text("\(count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func timeScopeSectionHeader(scope: TaskTimeScope, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if collapsedScopes.contains(scope) {
                    collapsedScopes.remove(scope)
                } else {
                    collapsedScopes.insert(scope)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: scope.symbolName)
                    .font(.caption2)
                    .foregroundStyle(scope.color)

                Text(scope.label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)

                Spacer()

                Text("\(count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.quaternary)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.quaternary)
                    .rotationEffect(collapsedScopes.contains(scope) ? .degrees(-90) : .zero)
                    .animation(.easeInOut(duration: 0.2), value: collapsedScopes.contains(scope))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func doneSectionHeader(count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDoneExpanded.toggle()
            }
        } label: {
            HStack {
                Text("已完成".uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)

                Spacer()

                Text("\(count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.quaternary)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.quaternary)
                    .rotationEffect(isDoneExpanded ? .degrees(-180) : .zero)
                    .animation(.easeInOut(duration: 0.2), value: isDoneExpanded)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Actions

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            store.addTask(title: trimmed, category: newTaskCategory, timeScope: newTaskTimeScope)
        }
        newTaskTitle = ""
    }
}

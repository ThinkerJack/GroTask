import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TaskPopoverView: View {
    var store: TaskStore
    @State private var newTaskTitle = ""
    @State private var newTaskCategory: TaskCategory = .work
    @State private var newTaskTimeScope: TaskTimeScope = .anytime
    @State private var selectedScope: TaskTimeScope? = .today
    @State private var listContentHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    private let maxListHeight: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GroTask")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    isInputFocused = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("添加新任务")
                .accessibilityLabel("添加新任务")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Scope tab bar
            scopeTabBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider().opacity(0.3)

            // Task list
            if store.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                    Text("暂无任务")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let scope = selectedScope {
                // 筛选视图：只显示选中视角
                let pinned = store.pinnedTasks
                let scopeTasks = store.tasks(for: scope)
                if pinned.isEmpty && scopeTasks.isEmpty {
                    scopeEmptyView(scope)
                } else {
                    taskListScrollView {
                        VStack(spacing: 0) {
                            if !pinned.isEmpty {
                                pinnedSectionHeader(count: pinned.count)
                                taskRows(pinned)
                            }
                            taskRows(scopeTasks)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                // 已完成视图
                let done = store.doneTasks
                if done.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.quaternary)
                        Text("暂无已完成任务")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    taskListScrollView {
                        VStack(spacing: 0) {
                            taskRows(done)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider().opacity(0.3)

            // Quick-add input with Liquid Glass effect
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            newTaskCategory = newTaskCategory.next
                        }
                    } label: {
                        Circle()
                            .fill(newTaskCategory.color)
                            .frame(width: 10, height: 10)
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
                            .font(.callout)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Footer
            HStack {
                Spacer()
                Button("退出 GroTask") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 320)
    }

    // MARK: - Task List ScrollView

    @ViewBuilder
    private func taskListScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let height = min(max(listContentHeight, 1), maxListHeight)
        ScrollView {
            content()
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                listContentHeight = geo.size.height
                            }
                            .onChange(of: geo.size.height) { _, newHeight in
                                listContentHeight = newHeight
                            }
                    }
                )
        }
        .frame(height: height)
    }

    // MARK: - Scope Tab Bar

    private var scopeTabBar: some View {
        HStack(spacing: 4) {
            ForEach(TaskTimeScope.allCases) { scope in
                scopeTabButton(scope: scope, isSelected: selectedScope == scope)
            }
            scopeTabButton(label: "完成", icon: "checkmark.circle", color: .green, isSelected: selectedScope == nil) {
                selectedScope = nil
            }
        }
    }

    private func scopeTabButton(scope: TaskTimeScope, isSelected: Bool) -> some View {
        scopeTabButton(label: scope.label, icon: scope.symbolName, color: scope.color, isSelected: isSelected) {
            selectedScope = scope
            newTaskTimeScope = scope
        }
    }

    private func scopeTabButton(label: String, icon: String, color: Color = .secondary, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isSelected ? color : .secondary)
            .background(isSelected ? color.opacity(0.12) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func scopeEmptyView(_ scope: TaskTimeScope) -> some View {
        VStack(spacing: 8) {
            Image(systemName: scope.symbolName)
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("\(scope.label)暂无任务")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
                },
                onSetTimeScope: { scope in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.setTimeScope(id: task.id, scope: scope)
                    }
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
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("今天".uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            Spacer()

            Text("\(count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
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

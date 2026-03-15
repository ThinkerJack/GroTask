import SwiftUI

struct TaskListView: View {
    var store: TaskStore
    @State private var newTaskTitle = ""
    @State private var newTaskCategory: TaskCategory = .work
    @State private var newTaskTimeScope: TaskTimeScope = .anytime
    @State private var selectedScope: TaskTimeScope? = .today
    @State private var isDoneExpanded = false
    @State private var collapsedScopes: Set<TaskTimeScope> = [.someday]
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                taskList
                inputBar
            }
            .navigationTitle("GroTask")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .top, spacing: 0) {
                scopeTabBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.refreshFromStore()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("刷新同步")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isInputFocused = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("添加新任务")
                }
            }
        }
    }

    // MARK: - Task List

    @ViewBuilder
    private var taskList: some View {
        if store.tasks.isEmpty {
            ContentUnavailableView("暂无任务", systemImage: "checkmark.circle", description: Text("点击右上角 + 添加新任务"))
        } else if let scope = selectedScope {
            // 筛选视图
            let pinned = store.pinnedTasks
            let scopeTasks = store.tasks(for: scope)
            if pinned.isEmpty && scopeTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: scope.symbolName)
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                    Text("\(scope.label)暂无任务")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !pinned.isEmpty {
                        Section {
                            taskRows(pinned)
                        } header: {
                            Label("置顶", systemImage: "pin.fill")
                        }
                    }
                    Section {
                        taskRows(scopeTasks)
                    }
                }
                .listStyle(.insetGrouped)
                .contentMargins(.bottom, 70)
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    store.refreshFromStore()
                }
            }
        } else {
            // 全部视图
            List {
                let pinned = store.pinnedTasks
                if !pinned.isEmpty {
                    Section {
                        taskRows(pinned)
                    } header: {
                        Label("置顶", systemImage: "pin.fill")
                    }
                }

                ForEach(TaskTimeScope.allCases) { scope in
                    let scopeTasks = store.tasks(for: scope)
                    if !scopeTasks.isEmpty {
                        Section {
                            if !collapsedScopes.contains(scope) {
                                taskRows(scopeTasks)
                            }
                        } header: {
                            Button {
                                withAnimation {
                                    if collapsedScopes.contains(scope) {
                                        collapsedScopes.remove(scope)
                                    } else {
                                        collapsedScopes.insert(scope)
                                    }
                                }
                            } label: {
                                HStack {
                                    Label(scope.label, systemImage: scope.symbolName)
                                        .foregroundStyle(scope.color)
                                    Spacer()
                                    Text("\(scopeTasks.count)")
                                        .foregroundStyle(.tertiary)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .rotationEffect(collapsedScopes.contains(scope) ? .degrees(-90) : .zero)
                                        .animation(.easeInOut(duration: 0.2), value: collapsedScopes.contains(scope))
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                let done = store.doneTasks
                if !done.isEmpty {
                    Section {
                        if isDoneExpanded {
                            taskRows(done)
                        }
                    } header: {
                        Button {
                            withAnimation { isDoneExpanded.toggle() }
                        } label: {
                            HStack {
                                Text("已完成")
                                Spacer()
                                Text("\(done.count)")
                                    .foregroundStyle(.tertiary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .rotationEffect(isDoneExpanded ? .degrees(-180) : .zero)
                                    .animation(.easeInOut(duration: 0.2), value: isDoneExpanded)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.bottom, 70)
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                store.refreshFromStore()
            }
        }
    }

    @ViewBuilder
    private func taskRows(_ tasks: [TaskItem]) -> some View {
        ForEach(tasks) { task in
            iOSTaskRowView(
                task: task,
                onCycleStatus: {
                    withAnimation { store.cycleStatus(id: task.id) }
                },
                onDelete: {
                    withAnimation { store.deleteTask(id: task.id) }
                },
                onToggleCategory: {
                    withAnimation { store.toggleCategory(id: task.id) }
                },
                onTogglePin: {
                    withAnimation { store.togglePin(id: task.id) }
                },
                onUpdateTitle: { newTitle in
                    store.updateTitle(id: task.id, newTitle: newTitle)
                },
                onSetTimeScope: { scope in
                    withAnimation { store.setTimeScope(id: task.id, scope: scope) }
                }
            )
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                )
            )
        }
    }

    // MARK: - Scope Tab Bar

    private var scopeTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskTimeScope.displayOrder) { scope in
                    scopeTabButton(label: scope.label, icon: scope.symbolName, color: scope.color, isSelected: selectedScope == scope) {
                        selectedScope = scope
                        newTaskTimeScope = scope
                    }
                }
                scopeTabButton(label: "完成", icon: "checkmark.circle", color: .green, isSelected: selectedScope == nil) {
                    selectedScope = nil
                }
            }
        }
    }

    private func scopeTabButton(label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? color : .secondary)
            .background(isSelected ? color.opacity(0.12) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        newTaskCategory = newTaskCategory.next
                    }
                } label: {
                    Circle()
                        .fill(newTaskCategory.color)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel("类别：\(newTaskCategory.label)")
                .accessibilityHint("双击切换为\(newTaskCategory.next.label)")

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
                .frame(width: 44, height: 44)
                .accessibilityLabel("时间视角：\(newTaskTimeScope.label)")
                .accessibilityHint("双击切换时间视角")

                TextField("新任务...", text: $newTaskTitle)
                    .font(.body)
                    .focused($isInputFocused)
                    .onSubmit { addTask() }

                if !newTaskTitle.isEmpty {
                    Button(action: addTask) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                    .accessibilityLabel("添加任务")
                    .frame(minWidth: 44, minHeight: 44)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            store.addTask(title: trimmed, category: newTaskCategory, timeScope: newTaskTimeScope)
        }
        newTaskTitle = ""
    }

}

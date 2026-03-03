import SwiftUI

struct TaskListView: View {
    var store: TaskStore
    @State private var newTaskTitle = ""
    @State private var newTaskCategory: TaskCategory = .work
    @State private var newTaskTimeScope: TaskTimeScope = .anytime
    @State private var isDoneExpanded = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                taskList
                inputBar
            }
            .navigationTitle("GroTask")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
        } else {
        List {
            let pinned = store.pinnedTasks
            if !pinned.isEmpty {
                Section {
                    taskRows(pinned)
                } header: {
                    Label("今天", systemImage: "pin.fill")
                }
            }

            let unpinned = store.unpinnedTasks
            if !unpinned.isEmpty {
                Section("待办") {
                    taskRows(unpinned)
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

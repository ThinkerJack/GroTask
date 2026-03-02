import SwiftUI

struct TaskListView: View {
    @State var store: TaskStore
    @State private var newTaskTitle = ""
    @State private var newTaskCategory: TaskCategory = .work
    @State private var isDoneExpanded = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                taskList
                inputBar
            }
            .navigationTitle("GroTask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isInputFocused = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
    }

    // MARK: - Task List

    private var taskList: some View {
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
                                .foregroundStyle(.secondary)
                            Image(systemName: isDoneExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.bottom, 60) // 为底部输入栏留空间
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
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    newTaskCategory = newTaskCategory.next
                }
            } label: {
                Circle()
                    .fill(newTaskCategory.color)
                    .frame(width: 10, height: 10)
            }

            TextField("新任务...", text: $newTaskTitle)
                .focused($isInputFocused)
                .onSubmit { addTask() }

            if !newTaskTitle.isEmpty {
                Button(action: addTask) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            store.addTask(title: trimmed, category: newTaskCategory)
        }
        newTaskTitle = ""
    }
}

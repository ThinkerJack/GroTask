import SwiftUI

struct TaskPopoverView: View {
    @State var store: TaskStore
    @State private var newTaskTitle = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GroTask")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    isInputFocused = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("添加新任务")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

            // Task list
            if store.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("暂无任务")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(TaskStatus.allCases) { status in
                            let tasksForStatus = store.tasks(for: status)
                            if !tasksForStatus.isEmpty {
                                sectionHeader(status: status, count: tasksForStatus.count)

                                ForEach(tasksForStatus) { task in
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
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider().opacity(0.5)

            // Quick-add input
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                TextField("新任务...", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
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
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .frame(width: 320)
    }

    // MARK: - Subviews

    private func sectionHeader(status: TaskStatus, count: Int) -> some View {
        HStack {
            Text(status.label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            Spacer()

            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Actions

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            store.addTask(title: trimmed)
        }
        newTaskTitle = ""
    }
}

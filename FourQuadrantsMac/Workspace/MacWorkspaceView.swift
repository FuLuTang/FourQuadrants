import SwiftData
import SwiftUI

struct MacWorkspaceView: View {
    @Environment(MacApplicationRuntime.self) private var runtime
    @Environment(TaskStore.self) private var taskStore
    @Environment(MacStickyCoordinator.self) private var stickyCoordinator
    @Query(sort: \QuadrantTask.updatedAt, order: .reverse) private var tasks: [QuadrantTask]

    @State private var selection: MacWorkspaceRoute? = .quadrants
    @State private var searchText = ""
    @State private var sortMethod: TaskStore.TaskSortMethod = .intelligence
    @State private var selectedTaskID: UUID?
    @State private var prefersInspectorPresented = true
    @State private var isTaskFormPresented = false
    @State private var isShowingDeleteConfirmation = false
    @State private var pendingDeleteID: UUID?
    @State private var taskToEdit: QuadrantTask?
    @State private var isShowingStoreError = false
    @State private var refreshDate = Date()

    private var selectedTask: QuadrantTask? {
        tasks.first { $0.id == selectedTaskID }
    }

    private var filteredTasks: [QuadrantTask] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var completionExpiry: Date? {
        MacCompletionVisibility.nextExpiry(of: tasks, after: refreshDate)
    }

    private var inspectorPresentation: Binding<Bool> {
        Binding(
            get: { (selection ?? .quadrants).supportsInspector && prefersInspectorPresented },
            set: { isPresented in
                guard (selection ?? .quadrants).supportsInspector else { return }
                prefersInspectorPresented = isPresented
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            MacWorkspaceSidebar(selection: $selection, tasks: tasks)
        } detail: {
            MacWorkspaceContent(
                selection: selection ?? .quadrants,
                tasks: filteredTasks,
                taskStore: taskStore,
                sortMethod: sortMethod,
                now: refreshDate,
                selectedTaskID: $selectedTaskID,
                onEdit: presentEditForm,
                onDelete: requestDelete,
                onPin: pinTask
            )
            .searchable(text: $searchText, placement: .toolbar, prompt: "搜索任务")
            .navigationTitle((selection ?? .quadrants).navigationTitle)
            .toolbar {
                MacWorkspaceToolbar(
                    route: selection ?? .quadrants,
                    stickyCoordinator: stickyCoordinator,
                    sortMethod: $sortMethod,
                    prefersInspectorPresented: $prefersInspectorPresented,
                    onNewTask: presentNewTask
                )
            }
            .inspector(isPresented: inspectorPresentation) {
                if (selection ?? .quadrants).supportsInspector {
                    MacTaskInspector(
                        task: selectedTask,
                        taskStore: taskStore,
                        onEditDetails: { task in presentEditForm(task) },
                        onPin: { task in pinTask(task) }
                    )
                    .inspectorColumnWidth(min: 230, ideal: 275, max: 340)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $isTaskFormPresented, onDismiss: { taskToEdit = nil }) {
            MacTaskFormView(taskStore: taskStore, existingTask: taskToEdit)
                .frame(minWidth: 460, minHeight: 420)
        }
        .confirmationDialog("删除此任务？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除任务", role: .destructive) { deletePendingTask() }
            Button("取消", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("删除后无法从本地恢复此任务。")
        }
        .alert("保存失败", isPresented: $isShowingStoreError) {
            Button("好", role: .cancel) { taskStore.dismissLastError() }
        } message: {
            Text(taskStore.lastErrorMessage ?? "请重试。")
        }
        .onChange(of: taskStore.lastErrorMessage) { _, value in
            isShowingStoreError = value != nil
        }
        // Re-snapshot `refreshDate` only when a just-completed task is due to
        // leave the quadrants; the id changes whenever that deadline changes.
        .task(id: completionExpiry) { await refreshWhenCompletionExpires() }
        .onAppear(perform: handlePendingRoute)
        .onChange(of: runtime.pendingRoute) { _, _ in
            handlePendingRoute()
        }
    }

    private func refreshWhenCompletionExpires() async {
        guard let expiry = completionExpiry else { return }
        let delay = expiry.timeIntervalSinceNow
        if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
        guard !Task.isCancelled else { return }
        refreshDate = Date()
    }

    private func presentNewTask() {
        taskToEdit = nil
        isTaskFormPresented = true
    }

    private func handlePendingRoute() {
        switch runtime.consumePendingRoute() {
        case .newTask:
            presentNewTask()
        case .showTask(let id):
            selection = .all
            searchText = ""
            selectedTaskID = id
            prefersInspectorPresented = true
        case nil:
            break
        }
    }

    private func presentEditForm(_ task: QuadrantTask) {
        taskToEdit = task
        isTaskFormPresented = true
    }

    private func requestDelete(_ task: QuadrantTask) {
        pendingDeleteID = task.id
        isShowingDeleteConfirmation = true
    }

    private func deletePendingTask() {
        defer { pendingDeleteID = nil }
        guard let id = pendingDeleteID, let task = tasks.first(where: { $0.id == id }) else { return }
        let deleted = taskStore.removeTask(task)
        if deleted && selectedTaskID == id { selectedTaskID = nil }
    }

    private func pinTask(_ task: QuadrantTask) {
        stickyCoordinator.createNote(source: .category(task.category))
    }
}

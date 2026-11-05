import Combine
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
    @State private var sortDirection: TaskStore.TaskSortDirection = .ascending
    @State private var selectedTaskID: UUID?
    @State private var prefersInspectorPresented = true
    @State private var isTaskFormPresented = false
    @State private var isShowingDeleteConfirmation = false
    @State private var pendingDeleteID: UUID?
    @State private var taskToEdit: QuadrantTask?
    @State private var isShowingStoreError = false
    @State private var refreshDate = Date()

    /// 当前路由；未选中任何侧边栏项时回到四象限。
    private var route: MacWorkspaceRoute { selection ?? .quadrants }

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

    /// 一次性构造的任务操作集合，向下传递给列表、看板与任务行。
    private var taskActions: MacTaskActions {
        MacTaskActions(
            select: { selectedTaskID = $0.id },
            edit: presentEditForm,
            delete: requestDelete,
            pin: pinTask,
            toggleCompletion: { _ = taskStore.toggleTask($0) },
            // 已完成任务没有移动入口，这里统一拒绝。
            move: { task, category in !task.isCompleted && taskStore.moveTask(task, to: category) }
        )
    }

    private var inspectorPresentation: Binding<Bool> {
        Binding(
            get: { route.supportsInspector && prefersInspectorPresented },
            set: { isPresented in
                guard route.supportsInspector else { return }
                prefersInspectorPresented = isPresented
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            MacWorkspaceSidebar(selection: $selection, tasks: tasks)
        } detail: {
            MacWorkspaceContent(
                selection: route,
                tasks: filteredTasks,
                taskStore: taskStore,
                sortMethod: sortMethod,
                sortDirection: sortDirection,
                now: refreshDate,
                selectedTaskID: $selectedTaskID,
                actions: taskActions
            )
            .searchable(text: $searchText, placement: .toolbar, prompt: "搜索任务")
            // 文本框聚焦时 Delete 键由文本框处理，不会走到这里，因此不会误删任务。
            .onDeleteCommand {
                guard route.supportsInspector, let selectedTask else { return }
                requestDelete(selectedTask)
            }
            .navigationTitle(route.navigationTitle)
            .toolbar {
                MacWorkspaceToolbar(
                    route: route,
                    stickyCoordinator: stickyCoordinator,
                    sortMethod: $sortMethod,
                    sortDirection: $sortDirection,
                    prefersInspectorPresented: $prefersInspectorPresented,
                    onNewTask: presentNewTask
                )
            }
            .inspector(isPresented: inspectorPresentation) {
                if route.supportsInspector {
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
            if let message = taskStore.lastErrorMessage { Text(verbatim: message) } else { Text("请重试。") }
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
        // 跨过零点后截止日期的紧急状态会变化，需要重新计算；回到前台时也刷新一次。
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            refreshDate = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification).receive(on: DispatchQueue.main)) { _ in
            refreshDate = Date()
        }
        // 切换到新的排序方式时方向重置为升序，与 iOS 一致。
        .onChange(of: sortMethod) { _, _ in
            sortDirection = .ascending
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
        stickyCoordinator.showOrCreateNote(source: .category(task.category))
    }
}

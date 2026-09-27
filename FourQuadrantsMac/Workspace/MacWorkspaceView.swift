import Combine
import SwiftData
import SwiftUI

private enum MacWorkspaceRoute: Hashable {
    case quadrants
    case daily
    case all
    case completed
    case stickies
    case category(TaskCategory)

    var supportsInspector: Bool {
        self != .daily && self != .stickies
    }

    var navigationTitle: Text {
        switch self {
        case .quadrants: Text("四象限")
        case .daily: Text("日程")
        case .all: Text("全部任务")
        case .completed: Text("已完成")
        case .stickies: Text("桌面便笺")
        case let .category(category): Text(category.displayName)
        }
    }
}

struct MacWorkspaceView: View {
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
            .toolbar { workspaceToolbar }
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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { instant in
            let needsCompletionRefresh = tasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                let ageAtLastRefresh = refreshDate.timeIntervalSince(completedAt)
                let completedAfterSnapshot = ageAtLastRefresh < 0
                let visibleAtSnapshot = ageAtLastRefresh >= 0 && ageAtLastRefresh < 3
                return (completedAfterSnapshot || visibleAtSnapshot) && instant > refreshDate
            }
            if needsCompletionRefresh { refreshDate = instant }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macCreateTask)) { _ in
            presentNewTask()
        }
        .onReceive(NotificationCenter.default.publisher(for: .macShowTask)) { notification in
            guard let id = notification.object as? UUID else { return }
            selection = .all
            searchText = ""
            selectedTaskID = id
            prefersInspectorPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .macNavigate)) { notification in
            guard let destination = notification.object as? String else { return }
            switch destination {
            case "quadrants": selection = .quadrants
            case "daily": selection = .daily
            case "all": selection = .all
            case "completed": selection = .completed
            case "stickies": selection = .stickies
            default: break
            }
        }
    }

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button("新建任务", systemImage: "plus") { presentNewTask() }
                Menu("放到桌面") {
                    ForEach(MacWorkspaceSidebar.quadrants, id: \.self) { category in
                        Button(category.displayName, systemImage: category.icon) {
                            stickyCoordinator.pinCategory(category)
                        }
                    }
                }
            } label: {
                Label("新建", systemImage: "plus")
            }
            .help("新建任务或将象限放到桌面")

            Menu {
                Button("智能排序") { sortMethod = .intelligence }
                Button("截止日期") { sortMethod = .byDueDate }
                Button("创建时间") { sortMethod = .byCreationDate }
                Button("名称") { sortMethod = .byName }
            } label: {
                Label("排序", systemImage: "arrow.up.arrow.down")
            }
            .help("更改任务排序方式")

            if (selection ?? .quadrants).supportsInspector {
                Button {
                    prefersInspectorPresented.toggle()
                } label: {
                    Label("显示检查器", systemImage: "sidebar.right")
                }
                .help("显示或隐藏任务检查器")
            }
        }
    }

    private func presentNewTask() {
        taskToEdit = nil
        isTaskFormPresented = true
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
        guard let id = pendingDeleteID, let task = tasks.first(where: { $0.id == id }) else { return }
        let deleted = taskStore.removeTask(task)
        if deleted && selectedTaskID == id { selectedTaskID = nil }
        pendingDeleteID = nil
    }

    private func pinTask(_ task: QuadrantTask) {
        stickyCoordinator.pinTasks([task.id], title: task.title)
    }
}

private struct MacWorkspaceSidebar: View {
    @Binding var selection: MacWorkspaceRoute?
    let tasks: [QuadrantTask]

    static let quadrants: [TaskCategory] = [
        .importantAndUrgent,
        .urgentButNotImportant,
        .importantButNotUrgent,
        .notImportantAndNotUrgent
    ]

    var body: some View {
        List(selection: $selection) {
            Section("工作区") {
                Label("四象限", systemImage: "square.grid.2x2.fill")
                    .tag(MacWorkspaceRoute.quadrants)
                Label("日程", systemImage: "calendar")
                    .tag(MacWorkspaceRoute.daily)
                Label("全部任务", systemImage: "tray.full")
                    .badge(tasks.filter { !$0.isCompleted }.count)
                    .tag(MacWorkspaceRoute.all)
                Label("已完成", systemImage: "checkmark.circle")
                    .badge(tasks.filter(\.isCompleted).count)
                    .tag(MacWorkspaceRoute.completed)
                Label("桌面便笺", systemImage: "note.text")
                    .tag(MacWorkspaceRoute.stickies)
            }

            Section("象限") {
                ForEach(Self.quadrants, id: \.self) { category in
                    Label(category.displayName, systemImage: category.icon)
                        .foregroundStyle(category.themeColor)
                        .tag(MacWorkspaceRoute.category(category))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("四象限")
        .frame(minWidth: 190)
    }
}

private struct MacWorkspaceContent: View {
    let selection: MacWorkspaceRoute
    let tasks: [QuadrantTask]
    let taskStore: TaskStore
    let sortMethod: TaskStore.TaskSortMethod
    let now: Date
    @Binding var selectedTaskID: UUID?
    let onEdit: (QuadrantTask) -> Void
    let onDelete: (QuadrantTask) -> Void
    let onPin: (QuadrantTask) -> Void

    var body: some View {
        Group {
            switch selection {
            case .quadrants:
                MacQuadrantBoard(tasks: tasks, taskStore: taskStore, now: now, selectedTaskID: $selectedTaskID, onEdit: onEdit, onDelete: onDelete, onPin: onPin)
            case .daily:
                MacDailyView()
            case .all:
                MacTaskList(title: "全部任务", tasks: taskStore.filteredTasks(tasks, in: .all, now: now), sortMethod: sortMethod, taskStore: taskStore, selectedTaskID: $selectedTaskID, onEdit: onEdit, onDelete: onDelete, onPin: onPin)
            case .completed:
                MacTaskList(title: "已完成", tasks: taskStore.filteredTasks(tasks, in: .completed, now: now), sortMethod: sortMethod, taskStore: taskStore, selectedTaskID: $selectedTaskID, onEdit: onEdit, onDelete: onDelete, onPin: onPin)
            case .stickies:
                MacStickiesLibraryView()
            case let .category(category):
                MacTaskList(title: category.displayName, tasks: taskStore.filteredTasks(tasks, in: category, now: now), sortMethod: sortMethod, taskStore: taskStore, selectedTaskID: $selectedTaskID, onEdit: onEdit, onDelete: onDelete, onPin: onPin)
            }
        }
        .navigationTitle(selection.navigationTitle)
    }
}

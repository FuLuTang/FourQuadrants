import SwiftUI

/// Primary-action toolbar of the workspace detail column.
struct MacWorkspaceToolbar: ToolbarContent {
    let route: MacWorkspaceRoute
    let stickyCoordinator: MacStickyCoordinator
    @Binding var sortMethod: TaskStore.TaskSortMethod
    @Binding var prefersInspectorPresented: Bool
    let onNewTask: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Section("新建浮窗") {
                    MacStickyCreationMenuItems(stickies: stickyCoordinator, showsIcons: true)
                }

                if !stickyCoordinator.configurations.isEmpty {
                    Section("已保存的便笺") {
                        MacStickyExistingMenuItems(stickies: stickyCoordinator)
                    }
                }
            } label: {
                Label("添加ToDo便笺浮窗", systemImage: "note.text.badge.plus")
            }
            .help("创建、显示或隐藏 ToDo便笺浮窗")

            Button("新建任务", systemImage: "plus", action: onNewTask)
                .help("新建任务")

            if route.supportsSorting {
                Menu {
                    Picker("排序", selection: $sortMethod) {
                        Text("智能排序").tag(TaskStore.TaskSortMethod.intelligence)
                        Text("截止日期").tag(TaskStore.TaskSortMethod.byDueDate)
                        Text("创建时间").tag(TaskStore.TaskSortMethod.byCreationDate)
                        Text("名称").tag(TaskStore.TaskSortMethod.byName)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("排序", systemImage: "arrow.up.arrow.down")
                }
                .help("更改任务排序方式")
            }

            if route.supportsInspector {
                Button {
                    prefersInspectorPresented.toggle()
                } label: {
                    Label("显示检查器", systemImage: "sidebar.right")
                }
                .help("显示或隐藏任务检查器")
            }
        }
    }
}

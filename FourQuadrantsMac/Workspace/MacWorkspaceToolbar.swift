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
            if route == .quadrants {
                Menu {
                    Section("新建浮窗") {
                        MacStickyCreationMenuItems(stickies: stickyCoordinator, showsIcons: true)
                    }

                    if !stickyCoordinator.configurations.isEmpty {
                        Section("已保存的便笺") {
                            ForEach(stickyCoordinator.configurations) { configuration in
                                Menu {
                                    Button("打开便笺", systemImage: "arrow.up.forward.square") {
                                        stickyCoordinator.showWindow(for: configuration.id)
                                    }
                                    Button("删除便笺", systemImage: "trash", role: .destructive) {
                                        stickyCoordinator.removeConfiguration(id: configuration.id)
                                    }
                                } label: {
                                    Label {
                                        HStack(spacing: 4) {
                                            MacStickyConfigurationHeading(configuration: configuration)
                                            Text(configuration.isVisible ? "· 已打开" : "· 已隐藏")
                                        }
                                    } icon: {
                                        Image(systemName: "note.text")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label("添加ToDo便笺浮窗", systemImage: "note.text.badge.plus")
                        .fontWeight(.semibold)
                }
                .tint(.accentColor)
                .controlSize(.large)
                .help("创建、打开或删除 ToDo 便笺浮窗")
            }

            Menu {
                Button("新建任务", systemImage: "plus") { onNewTask() }
                Menu("放到桌面") {
                    ForEach(TaskCategory.allQuadrants, id: \.self) { category in
                        Button {
                            stickyCoordinator.createNote(source: .category(category))
                        } label: {
                            Label {
                                MacQuadrantHeading(category: category, font: .body)
                            } icon: {
                                Image(systemName: category.icon)
                            }
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

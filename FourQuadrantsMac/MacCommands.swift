import SwiftUI

/// App-level menu bar commands for the main window.
struct MacCommands: Commands {
    let runtime: MacApplicationRuntime

    var body: some Commands {
        SidebarCommands()
        CommandGroup(after: .newItem) {
            Button("新建任务") { runtime.requestNewTask() }
                .keyboardShortcut("n")
                .disabled(runtime.stickies == nil)
        }
        CommandMenu("ToDo便笺") {
            Menu("添加ToDo便笺浮窗") {
                MacStickyCreationMenuItems(stickies: runtime.stickies)
            }
            .disabled(runtime.stickies == nil)

            if let stickies = runtime.stickies, !stickies.configurations.isEmpty {
                Divider()
                MacStickyExistingMenuItems(stickies: stickies)
            }
        }
    }
}

/// 「已有便笺」的菜单项：每张便笺一项，勾选表示正在显示，点击切换显示与隐藏。
/// 删除便笺由便笺自身的右键菜单负责。
struct MacStickyExistingMenuItems: View {
    let stickies: MacStickyCoordinator?

    var body: some View {
        if let stickies {
            ForEach(stickies.configurations) { configuration in
                Toggle(isOn: visibilityBinding(for: configuration.id, in: stickies)) {
                    MacStickyConfigurationHeading(configuration: configuration)
                }
            }
        }
    }

    /// 读取时取最新状态，避免菜单停留在创建时的快照上。
    private func visibilityBinding(for id: UUID, in stickies: MacStickyCoordinator) -> Binding<Bool> {
        Binding(
            get: { stickies.configurations.first { $0.id == id }?.isVisible ?? false },
            set: { isVisible in
                if isVisible {
                    stickies.showWindow(for: id)
                } else {
                    stickies.hideWindow(id: id)
                }
            }
        )
    }
}

/// The "add sticky" entries shared by the menu bar, the app menu and the workspace toolbar.
struct MacStickyCreationMenuItems: View {
    let stickies: MacStickyCoordinator?
    var showsIcons = false

    var body: some View {
        ForEach(TaskCategory.allQuadrants, id: \.self) { category in
            Button {
                stickies?.createNote(source: .category(category))
            } label: {
                if showsIcons {
                    Label {
                        MacQuadrantHeading(category: category, font: .body)
                    } icon: {
                        Image(systemName: category.icon)
                    }
                } else {
                    MacQuadrantHeading(category: category, font: .body)
                }
            }
        }
        Divider()
        if showsIcons {
            Button("四合一", systemImage: "square.grid.2x2") { stickies?.createNote(source: .combined) }
            Button("智能排列", systemImage: "sparkles.rectangle.stack") { stickies?.createNote(source: .smart) }
        } else {
            Button("四合一") { stickies?.createNote(source: .combined) }
            Button("智能排列") { stickies?.createNote(source: .smart) }
        }
    }
}

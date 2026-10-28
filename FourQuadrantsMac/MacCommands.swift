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
        }
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

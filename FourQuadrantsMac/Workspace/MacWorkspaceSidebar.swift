import SwiftUI

struct MacWorkspaceSidebar: View {
    @Binding var selection: MacWorkspaceRoute?
    let tasks: [QuadrantTask]

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
            }

            Section("象限") {
                ForEach(TaskCategory.allQuadrants, id: \.self) { category in
                    Label {
                        MacQuadrantHeading(category: category, font: .body)
                    } icon: {
                        Image(systemName: category.icon)
                    }
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

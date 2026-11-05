import AppKit
import SwiftData
import SwiftUI

struct MacStickyNoteView: View {
    let configurationID: UUID
    @Environment(MacStickyCoordinator.self) private var coordinator
    @Query(sort: \QuadrantTask.updatedAt, order: .reverse) private var allTasks: [QuadrantTask]
    /// 刚完成的任务显示 3 秒后消失；只在到期时刷新一次，不做逐秒刷新。
    @State private var expiryTick = 0
    /// 内容区是否显示：收起时立即隐藏；展开时等窗口动画结束再显示，避免内容随窗口逐帧重排。
    @State private var contentShown = true

    var body: some View {
        if let configuration = coordinator.configurations.first(where: { $0.id == configurationID }) {
            let _ = expiryTick
            let now = Date()
            let source = configuration.source
            let tasks = coordinator.visibleTasks(from: configuration.source, in: allTasks, now: now)
            let error = coordinator.persistenceError ?? coordinator.taskStore.lastErrorMessage
            VStack(spacing: 0) {
                MacStickyTitleBar(
                    configuration: configuration,
                    source: source,
                    openCount: configuration.isCollapsed ? tasks.filter { !$0.isCompleted }.count : nil
                )
                if !configuration.isCollapsed && contentShown {
                    Group {
                        if source == .combined {
                            MacStickyCombinedGrid(
                                tasksFor: { coordinator.visibleTasks(from: .category($0), in: allTasks, now: now) },
                                showDetails: configuration.showDetails,
                                onToggle: toggle,
                                onOpen: open
                            )
                        } else {
                            MacStickyTaskList(tasks: tasks, showDetails: configuration.showDetails, tintsRows: source == .smart, onToggle: toggle, onOpen: open)
                        }
                    }
                    if let error {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                    }
                }
            }
            .foregroundStyle(MacStickyPalette.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(source.bodyColor)
            .overlay(Rectangle().strokeBorder(.black.opacity(0.28), lineWidth: 1))
            .overlay {
                // 收起态不可缩放，不显示缩放光标。
                if !configuration.isCollapsed { MacStickyResizeCursors() }
            }
            .overlay(alignment: .bottomTrailing) {
                if !configuration.isCollapsed && contentShown {
                    MacStickyResizeCorner().frame(width: 10, height: 10)
                }
            }
            .task(id: configuration.isCollapsed) {
                if configuration.isCollapsed {
                    contentShown = false
                } else if !contentShown {
                    try? await Task.sleep(for: .seconds(MacStickyLayout.collapseAnimationDuration))
                    if !Task.isCancelled { contentShown = true }
                }
            }
            .task(id: nextExpiry(after: now)) {
                guard let expiry = nextExpiry(after: now) else { return }
                try? await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow) + 0.05))
                if !Task.isCancelled { expiryTick &+= 1 }
            }
        }
    }

    private func nextExpiry(after now: Date) -> Date? {
        allTasks
            .compactMap { $0.completedAt?.addingTimeInterval(TaskStore.completionVisibilityDuration) }
            .filter { $0 > now }
            .min()
    }

    private func toggle(_ task: QuadrantTask) { _ = coordinator.taskStore.toggleTask(task) }
    private func open(_ task: QuadrantTask) { coordinator.openTaskInMainApp(task.id) }
}

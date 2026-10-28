import AppKit
import SwiftData
import SwiftUI

/// 便笺纸张固定为浅色，不随系统深色模式变化，文字始终为深色。
private enum MacStickyPalette {
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    /// 原版 Stickies 的黄：正文 #FEF49C，标题条 #FEEA3D。
    static let yellowBody = Color(red: 254 / 255, green: 244 / 255, blue: 156 / 255)
    static let yellowBar = Color(red: 254 / 255, green: 234 / 255, blue: 61 / 255)

    /// 向白色混合，得到分类色的浅色调。
    static func tint(_ color: Color, toward fraction: Double) -> Color {
        let base = NSColor(color).usingColorSpace(.sRGB) ?? .gray
        return Color(nsColor: base.blended(withFraction: fraction, of: .white) ?? base)
    }
}

enum MacStickyMode: CaseIterable, Identifiable {
    case importantAndUrgent
    case importantButNotUrgent
    case urgentButNotImportant
    case notImportantAndNotUrgent
    case combined
    case smart

    var id: Self { self }

    var title: String { source.title }

    var source: MacStickySource {
        switch self {
        case .importantAndUrgent: .category(.importantAndUrgent)
        case .importantButNotUrgent: .category(.importantButNotUrgent)
        case .urgentButNotImportant: .category(.urgentButNotImportant)
        case .notImportantAndNotUrgent: .category(.notImportantAndNotUrgent)
        case .combined: .combined
        case .smart: .smart
        }
    }

    /// 单象限便笺对应的分类；四合一与智能排列没有。
    fileprivate var category: TaskCategory? {
        if case .category(let category) = source { return category }
        return nil
    }

    fileprivate var bodyColor: Color {
        guard let category else { return MacStickyPalette.yellowBody }
        return MacStickyPalette.tint(category.themeColor, toward: 0.84)
    }

    fileprivate var barColor: Color {
        guard let category else { return MacStickyPalette.yellowBar }
        return MacStickyPalette.tint(category.themeColor, toward: 0.64)
    }

    init(source: MacStickySource) {
        switch source {
        case .category(.importantAndUrgent): self = .importantAndUrgent
        case .category(.importantButNotUrgent): self = .importantButNotUrgent
        case .category(.urgentButNotImportant): self = .urgentButNotImportant
        case .category(.notImportantAndNotUrgent): self = .notImportantAndNotUrgent
        case .combined: self = .combined
        case .smart, .selectedTaskIDs, .category(.all), .category(.completed): self = .smart
        }
    }
}

struct MacStickyNoteView: View {
    let configurationID: UUID
    @Environment(MacStickyCoordinator.self) private var coordinator
    @Query(sort: \QuadrantTask.updatedAt, order: .reverse) private var allTasks: [QuadrantTask]
    /// 刚完成的任务显示 3 秒后消失；只在到期时刷新一次，不做逐秒刷新。
    @State private var expiryTick = 0

    var body: some View {
        if let configuration = coordinator.configurations.first(where: { $0.id == configurationID }) {
            let _ = expiryTick
            let now = Date()
            let mode = MacStickyMode(source: configuration.source)
            let tasks = coordinator.visibleTasks(from: configuration.source, in: allTasks, now: now)
            let error = coordinator.persistenceError ?? coordinator.taskStore.lastErrorMessage
            VStack(spacing: 0) {
                MacStickyTitleBar(
                    configuration: configuration,
                    mode: mode,
                    openCount: configuration.isCollapsed ? tasks.filter { !$0.isCompleted }.count : nil
                )
                if !configuration.isCollapsed {
                    Group {
                        if mode == .combined {
                            MacStickyCombinedGrid(tasks: tasks, showDetails: configuration.showDetails, onToggle: toggle, onOpen: open)
                        } else {
                            MacStickyTaskList(tasks: tasks, showDetails: configuration.showDetails, onToggle: toggle, onOpen: open)
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
            .background(mode.bodyColor)
            .overlay(Rectangle().strokeBorder(.black.opacity(0.28), lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                if !configuration.isCollapsed {
                    MacStickyResizeCorner().frame(width: 10, height: 10)
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

// MARK: - 标题条

private struct MacStickyTitleBar: View {
    let configuration: MacStickyConfiguration
    let mode: MacStickyMode
    /// 仅收起态显示未完成数量。
    let openCount: Int?
    @Environment(MacStickyCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            MacStickyDragArea(
                onDoubleClick: { coordinator.setCollapsed(!configuration.isCollapsed, id: configuration.id) },
                menuProvider: { currentFullMenu() }
            )
            HStack(spacing: 0) {
                controlBox(label: "隐藏浮窗") { coordinator.hideWindow(id: configuration.id) }
                modeButton
                Spacer(minLength: 0)
                controlBox(label: configuration.isCollapsed ? "展开任务列表" : "收起为标题条", showsShade: true) {
                    coordinator.setCollapsed(!configuration.isCollapsed, id: configuration.id)
                }
            }
        }
        .frame(height: MacStickyLayout.titleBarHeight)
        .background(mode.barColor)
    }

    /// 8pt 空心方框，外围 20×16 为点击区域。收起框内多一道横线，与关闭框区分。
    private func controlBox(label: String, showsShade: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Rectangle()
                .strokeBorder(MacStickyPalette.ink.opacity(0.55), lineWidth: 1)
                .overlay(alignment: .top) {
                    if showsShade {
                        Rectangle()
                            .fill(MacStickyPalette.ink.opacity(0.55))
                            .frame(height: 1)
                            .padding(.top, 3)
                    }
                }
                .frame(width: 8, height: 8)
                .frame(width: 20, height: MacStickyLayout.titleBarHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var modeButton: some View {
        Button {
            guard let event = NSApp.currentEvent, let view = event.window?.contentView else { return }
            let menu = MacStickyMenu.modeMenu(configuration: currentConfiguration, coordinator: coordinator)
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        } label: {
            HStack(spacing: 0) {
                if let category = mode.category {
                    MacQuadrantHeading(category: category, font: .system(size: 10))
                } else {
                    Text(mode.title).font(.system(size: 10))
                }
                if let openCount {
                    Text(" · \(openCount)").font(.system(size: 10)).monospacedDigit()
                }
            }
            .lineLimit(1)
            .foregroundStyle(MacStickyPalette.ink.opacity(0.8))
            .padding(.horizontal, 4)
            .frame(height: MacStickyLayout.titleBarHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("选择 ToDo便笺分类")
        .accessibilityLabel(mode.title)
        .accessibilityHint("选择要显示的 ToDo便笺分类")
    }

    private var currentConfiguration: MacStickyConfiguration {
        coordinator.configurations.first { $0.id == configuration.id } ?? configuration
    }

    private func currentFullMenu() -> NSMenu {
        MacStickyMenu.fullMenu(configuration: currentConfiguration, coordinator: coordinator)
    }
}

/// 标题条背景：拖动移动窗口、双击切换收起、右键弹出完整菜单。按钮叠在它上面。
private struct MacStickyDragArea: NSViewRepresentable {
    let onDoubleClick: () -> Void
    let menuProvider: () -> NSMenu?

    func makeNSView(context: Context) -> MacStickyDragView {
        MacStickyDragView(onDoubleClick: onDoubleClick, menuProvider: menuProvider)
    }

    func updateNSView(_ nsView: MacStickyDragView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
        nsView.menuProvider = menuProvider
    }
}

private final class MacStickyDragView: NSView {
    var onDoubleClick: () -> Void
    var menuProvider: () -> NSMenu?

    init(onDoubleClick: @escaping () -> Void, menuProvider: @escaping () -> NSMenu?) {
        self.onDoubleClick = onDoubleClick
        self.menuProvider = menuProvider
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick()
        } else {
            window?.performDrag(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? { menuProvider() }
}

/// 右下角 10pt 缩放热区：无边框面板的边缘缩放热区很窄，这里补一个稳妥的抓取点。
private struct MacStickyResizeCorner: NSViewRepresentable {
    func makeNSView(context: Context) -> MacStickyResizeView { MacStickyResizeView() }
    func updateNSView(_ nsView: MacStickyResizeView, context: Context) {}
}

private final class MacStickyResizeView: NSView {
    private var startMouse = NSPoint.zero
    private var startFrame = NSRect.zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startMouse = NSEvent.mouseLocation
        startFrame = window.frame
    }

    /// 左边界与上边界保持不变，只改变宽高。
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let width = max(window.minSize.width, startFrame.width + mouse.x - startMouse.x)
        let height = max(window.minSize.height, startFrame.height - (mouse.y - startMouse.y))
        window.setFrame(NSRect(x: startFrame.minX, y: startFrame.maxY - height, width: width, height: height), display: true)
    }
}

// MARK: - 内容

private struct MacStickyTaskList: View {
    let tasks: [QuadrantTask]
    let showDetails: Bool
    let onToggle: (QuadrantTask) -> Void
    let onOpen: (QuadrantTask) -> Void

    var body: some View {
        if tasks.isEmpty {
            Text("没有任务")
                .font(.system(size: 11))
                .foregroundStyle(MacStickyPalette.ink.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(tasks, id: \.id) { task in
                        MacStickyTaskRow(task: task, showDetails: showDetails, onToggle: { onToggle(task) }, onOpen: { onOpen(task) })
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }
}

/// 2×2 四合一：每格 14pt 小标题（象限名 + 数量），格间 1pt 分隔线。
private struct MacStickyCombinedGrid: View {
    let tasks: [QuadrantTask]
    let showDetails: Bool
    let onToggle: (QuadrantTask) -> Void
    let onOpen: (QuadrantTask) -> Void

    private let divider = MacStickyPalette.ink.opacity(0.18)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                quadrant(.importantAndUrgent)
                Rectangle().fill(divider).frame(width: 1)
                quadrant(.importantButNotUrgent)
            }
            Rectangle().fill(divider).frame(height: 1)
            HStack(spacing: 0) {
                quadrant(.urgentButNotImportant)
                Rectangle().fill(divider).frame(width: 1)
                quadrant(.notImportantAndNotUrgent)
            }
        }
    }

    private func quadrant(_ category: TaskCategory) -> some View {
        let open = tasks.filter { $0.category == category && !$0.isCompleted }
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                Rectangle().fill(category.themeColor).frame(width: 6, height: 6)
                MacQuadrantHeading(category: category, font: .system(size: 10))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(open.count)").font(.system(size: 10)).monospacedDigit()
            }
            .foregroundStyle(MacStickyPalette.ink.opacity(0.75))
            .padding(.horizontal, 6)
            .frame(height: 14)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(open, id: \.id) { task in
                        MacStickyTaskRow(task: task, showDetails: showDetails, onToggle: { onToggle(task) }, onOpen: { onOpen(task) })
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 紧凑任务行：12pt 标题、12pt 勾选圈、行高约 20pt。双击或右键「在主窗口中打开」。
private struct MacStickyTaskRow: View {
    let task: QuadrantTask
    let showDetails: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(MacStickyPalette.ink.opacity(task.isCompleted ? 0.5 : 0.8))
                    .frame(width: 14, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "重新打开任务：\(task.title)" : "完成任务：\(task.title)")

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 12))
                    .lineLimit(showDetails ? 2 : 1)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(MacStickyPalette.ink.opacity(task.isCompleted ? 0.5 : 1))
                    .frame(minHeight: 20, alignment: .leading)
                if showDetails {
                    if let notes = task.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 10))
                            .lineLimit(2)
                            .foregroundStyle(MacStickyPalette.ink.opacity(0.65))
                    }
                    if let dueDate = task.displayDueDate {
                        Text(dueDate, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10))
                            .foregroundStyle(MacStickyPalette.ink.opacity(task.isOverdue ? 0.9 : 0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpen)
        .contextMenu {
            Button("在主窗口中打开", action: onOpen)
        }
    }
}

import AppKit
import SwiftData
import SwiftUI

private enum MacStickyPalette {
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.13)

    static func background(for category: TaskCategory) -> Color {
        switch category {
        case .importantAndUrgent: Color(red: 1.00, green: 0.84, blue: 0.86)
        case .importantButNotUrgent: Color(red: 0.82, green: 0.89, blue: 1.00)
        case .urgentButNotImportant: Color(red: 0.78, green: 0.97, blue: 0.88)
        case .notImportantAndNotUrgent, .all, .completed: Color(red: 0.90, green: 0.90, blue: 0.94)
        }
    }
}

private enum MacStickyMode: CaseIterable, Identifiable {
    case importantAndUrgent
    case importantButNotUrgent
    case urgentButNotImportant
    case notImportantAndNotUrgent
    case combined
    case smart

    var id: Self { self }

    var title: String {
        switch self {
        case .importantAndUrgent: TaskCategory.importantAndUrgent.displayName
        case .importantButNotUrgent: TaskCategory.importantButNotUrgent.displayName
        case .urgentButNotImportant: TaskCategory.urgentButNotImportant.displayName
        case .notImportantAndNotUrgent: TaskCategory.notImportantAndNotUrgent.displayName
        case .combined: "四合一"
        case .smart: "智能排列"
        }
    }

    var icon: String {
        switch self {
        case .importantAndUrgent: "exclamationmark.triangle.fill"
        case .importantButNotUrgent: "clock.fill"
        case .urgentButNotImportant: "bolt.fill"
        case .notImportantAndNotUrgent: "leaf.fill"
        case .combined: "square.grid.2x2.fill"
        case .smart: "sparkles"
        }
    }

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

    var background: Color {
        switch self {
        case .importantAndUrgent: MacStickyPalette.background(for: .importantAndUrgent)
        case .importantButNotUrgent: MacStickyPalette.background(for: .importantButNotUrgent)
        case .urgentButNotImportant: MacStickyPalette.background(for: .urgentButNotImportant)
        case .notImportantAndNotUrgent: MacStickyPalette.background(for: .notImportantAndNotUrgent)
        case .combined, .smart: Color(red: 0.96, green: 0.94, blue: 0.87)
        }
    }

    var foreground: Color {
        switch self {
        case .importantAndUrgent, .importantButNotUrgent, .urgentButNotImportant, .notImportantAndNotUrgent:
            MacStickyPalette.ink
        case .combined, .smart:
            MacStickyPalette.ink.opacity(0.82)
        }
    }

    init(source: MacStickySource) {
        switch source {
        case .category(.importantAndUrgent): self = .importantAndUrgent
        case .category(.importantButNotUrgent): self = .importantButNotUrgent
        case .category(.urgentButNotImportant): self = .urgentButNotImportant
        case .category(.notImportantAndNotUrgent): self = .notImportantAndNotUrgent
        case .combined: self = .combined
        case .smart: self = .smart
        case .category(.all), .category(.completed), .selectedTaskIDs: self = .smart
        }
    }
}

struct MacStickyNoteView: View {
    let configurationID: UUID
    @Environment(MacStickyCoordinator.self) private var coordinator
    @Query(sort: \QuadrantTask.updatedAt, order: .reverse) private var allTasks: [QuadrantTask]

    init(configurationID: UUID) {
        self.configurationID = configurationID
    }

    var body: some View {
        if let configuration = coordinator.configurations.first(where: { $0.id == configurationID }) {
            let mode = MacStickyMode(source: configuration.source)
            VStack(spacing: 0) {
                MacStickyTitleBar(configuration: configuration, mode: mode)
                if !configuration.isCollapsed {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let tasks = coordinator.visibleTasks(from: configuration.source, in: allTasks, now: timeline.date)
                        if mode == .combined {
                            MacStickyCombinedGrid(
                                tasks: tasks.filter { !$0.isCompleted },
                                showDetails: configuration.showDetails,
                                error: coordinator.persistenceError ?? coordinator.taskStore.lastErrorMessage,
                                onToggle: { task in _ = coordinator.taskStore.toggleTask(task) },
                                onOpen: { task in coordinator.openTaskInMainApp(task.id) }
                            )
                        } else {
                            MacStickyTaskList(
                                tasks: tasks,
                                showDetails: configuration.showDetails,
                                error: coordinator.persistenceError ?? coordinator.taskStore.lastErrorMessage,
                                onToggle: { task in _ = coordinator.taskStore.toggleTask(task) },
                                onOpen: { task in coordinator.openTaskInMainApp(task.id) }
                            )
                        }
                    }
                }
            }
            .foregroundStyle(MacStickyPalette.ink)
            .background(mode.background.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: configuration.isCollapsed ? 15 : 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: configuration.isCollapsed ? 15 : 9).stroke(.black.opacity(0.14), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 3)
            .padding(1)
        } else {
            EmptyView()
        }
    }
}

private struct MacStickyTitleBar: View {
    let configuration: MacStickyConfiguration
    let mode: MacStickyMode
    @Environment(MacStickyCoordinator.self) private var coordinator

    @ViewBuilder
    private var modeHeading: some View {
        switch mode.source {
        case .category(let category) where category != .all && category != .completed:
            MacQuadrantHeading(category: category, font: .system(size: 11, weight: .semibold))
        default:
            Text(mode.title)
                .font(.system(size: 11, weight: .semibold))
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Button {
                coordinator.hideWindow(id: configuration.id)
            } label: {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(red: 0.89, green: 0.31, blue: 0.28))
                    .frame(width: 11, height: 11)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .black))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("隐藏浮窗")
            .accessibilityLabel("隐藏浮窗")

            Menu {
                Section("ToDo便笺分类") {
                    ForEach(MacStickyMode.allCases) { choice in
                        Button {
                            coordinator.updateSource(choice.source, for: configuration.id)
                        } label: {
                            if choice == mode {
                                Label(choice.title, systemImage: "checkmark")
                            } else {
                                Label(choice.title, systemImage: choice.icon)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: mode.icon)
                        .foregroundStyle(mode.foreground)
                    modeHeading
                        .lineLimit(1)
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 11, weight: .semibold))
                .frame(minHeight: 25)
            }
            .menuStyle(.borderlessButton)
            .help("选择 ToDo便笺分类")
            .accessibilityLabel(mode.title)
            .accessibilityHint("选择要显示的 ToDo便笺分类")

            MacStickyWindowDragHandle {
                coordinator.setCollapsed(!configuration.isCollapsed, id: configuration.id)
            }
                .frame(minWidth: 22, maxWidth: .infinity, minHeight: 25)
                .overlay {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .allowsHitTesting(false)
                }
                .help("拖动以移动浮窗")
                .accessibilityLabel("拖动以移动浮窗")

            MacStickySettingsMenu(configuration: configuration, mode: mode)
        }
        .padding(.horizontal, 6)
        .frame(height: 29)
        .background(
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.95, blue: 0.88), mode.background.opacity(0.84)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.1)).frame(height: 0.5) }
    }
}

private struct MacStickyWindowDragHandle: NSViewRepresentable {
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> MacStickyWindowDragView {
        let view = MacStickyWindowDragView(onDoubleClick: onDoubleClick)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel("拖动以移动浮窗")
        return view
    }

    func updateNSView(_ nsView: MacStickyWindowDragView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
    }
}

private final class MacStickyWindowDragView: NSView {
    var onDoubleClick: () -> Void

    init(onDoubleClick: @escaping () -> Void) {
        self.onDoubleClick = onDoubleClick
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick()
            return
        }
        window?.performDrag(with: event)
    }
}

private struct MacStickySettingsMenu: View {
    let configuration: MacStickyConfiguration
    let mode: MacStickyMode
    @Environment(MacStickyCoordinator.self) private var coordinator

    var body: some View {
        Menu {
            Section("显示模式") {
                ForEach(MacStickyMode.allCases) { choice in
                    Button {
                        coordinator.updateSource(choice.source, for: configuration.id)
                    } label: {
                        if choice == mode {
                            Label(choice.title, systemImage: "checkmark")
                        } else {
                            Label(choice.title, systemImage: choice.icon)
                        }
                    }
                }
            }

            Divider()
            Toggle("显示任务详情", isOn: Binding(
                get: { configuration.showDetails },
                set: { coordinator.updatePreferences(id: configuration.id, isFloating: configuration.isFloating, showDetails: $0) }
            ))
            Toggle("保持在其他窗口上方", isOn: Binding(
                get: { configuration.isFloating },
                set: { coordinator.updatePreferences(id: configuration.id, isFloating: $0, showDetails: configuration.showDetails) }
            ))
            Button {
                coordinator.setCollapsed(!configuration.isCollapsed, id: configuration.id)
            } label: {
                Label(configuration.isCollapsed ? "展开任务列表" : "收起为窄条", systemImage: "arrow.up.left.and.arrow.down.right")
            }

            Divider()
            Button("删除此浮窗配置", systemImage: "trash", role: .destructive) {
                coordinator.removeConfiguration(id: configuration.id)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 20, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .help("浮窗设置")
        .accessibilityLabel("浮窗设置")
    }
}

private struct MacStickyTaskList: View {
    let tasks: [QuadrantTask]
    let showDetails: Bool
    let error: String?
    let onToggle: (QuadrantTask) -> Void
    let onOpen: (QuadrantTask) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if tasks.isEmpty {
                ContentUnavailableView("没有符合条件的任务", systemImage: "checklist")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(tasks, id: \.id) { task in
                            MacStickyTaskRow(task: task, showDetails: showDetails, onToggle: { onToggle(task) }, onOpen: { onOpen(task) })
                        }
                    }
                    .padding(7)
                }
            }

            if let error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 9)
                    .padding(.bottom, 5)
            }
        }
    }
}

private struct MacStickyCombinedGrid: View {
    let tasks: [QuadrantTask]
    let showDetails: Bool
    let error: String?
    let onToggle: (QuadrantTask) -> Void
    let onOpen: (QuadrantTask) -> Void

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                quadrant(.importantAndUrgent)
                quadrant(.importantButNotUrgent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 1) {
                quadrant(.urgentButNotImportant)
                quadrant(.notImportantAndNotUrgent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.regularMaterial)
            }
        }
        .padding(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func quadrant(_ category: TaskCategory) -> some View {
        MacStickyQuadrantPanel(
            category: category,
            tasks: tasks.filter { $0.category == category },
            showDetails: showDetails,
            onToggle: onToggle,
            onOpen: onOpen
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MacStickyQuadrantPanel: View {
    let category: TaskCategory
    let tasks: [QuadrantTask]
    let showDetails: Bool
    let onToggle: (QuadrantTask) -> Void
    let onOpen: (QuadrantTask) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .foregroundStyle(category.themeColor)
                MacQuadrantHeading(category: category, font: .system(size: 10))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(tasks.count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .frame(height: 23)
            .background(MacStickyPalette.background(for: category))

            Rectangle()
                .fill(category.themeColor.opacity(0.32))
                .frame(height: 1)

            ScrollView {
                if tasks.isEmpty {
                    Text("暂无待办")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 3) {
                        ForEach(tasks, id: \.id) { task in
                            MacStickyTaskRow(
                                task: task,
                                showDetails: showDetails,
                                onToggle: { onToggle(task) },
                                onOpen: { onOpen(task) }
                            )
                        }
                    }
                    .padding(4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(MacStickyPalette.background(for: category).opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct MacStickyTaskRow: View {
    let task: QuadrantTask
    let showDetails: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(MacStickyPalette.ink.opacity(task.isCompleted ? 0.52 : 0.82))
                    .padding(.top, 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "重新打开任务：\(task.title)" : "完成任务：\(task.title)")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(showDetails ? 3 : 2)
                    .strikethrough(task.isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showDetails {
                    if let notes = task.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                        Text(notes)
                            .font(.caption2)
                            .foregroundStyle(MacStickyPalette.ink.opacity(0.7))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let dueDate = task.displayDueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(dueDate, format: .dateTime.month(.abbreviated).day())
                        }
                        .font(.caption2)
                        .foregroundStyle(MacStickyPalette.ink.opacity(task.isOverdue ? 0.9 : 0.64))
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onOpen)

            Menu {
                Button("在主页中打开", systemImage: "arrow.up.forward.app", action: onOpen)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(MacStickyPalette.ink.opacity(0.64))
                    .frame(width: 19, height: 23)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("任务操作：\(task.title)")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(MacStickyPalette.background(for: task.category).opacity(task.isCompleted ? 0.43 : 0.82))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

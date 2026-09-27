import AppKit
import SwiftData
import SwiftUI

private enum MacStickyPalette {
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
}

private extension MacStickyPaper {
    var color: Color {
        switch self {
        case .yellow: Color(red: 1.00, green: 0.94, blue: 0.63)
        case .blue: Color(red: 0.73, green: 0.86, blue: 0.98)
        case .green: Color(red: 0.76, green: 0.91, blue: 0.73)
        case .pink: Color(red: 0.98, green: 0.78, blue: 0.84)
        }
    }
}

struct MacStickiesLibraryView: View {
    @Environment(MacStickyCoordinator.self) private var coordinator
    @State private var editingConfiguration: MacStickyConfiguration?
    @State private var showingCategoryPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("桌面便笺", systemImage: "note.text")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button { coordinator.createEmptyNote() } label: {
                    Label("新建手选便笺", systemImage: "plus")
                }
                Button { showingCategoryPicker = true } label: {
                    Label("新建象限便笺", systemImage: "square.grid.2x2")
                }
            }
            .padding()

            if let error = coordinator.persistenceError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if coordinator.configurations.isEmpty {
                ContentUnavailableView("还没有便笺", systemImage: "note.text", description: Text("新建一张空白手选便笺，或按象限动态展示任务。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(coordinator.configurations) { configuration in
                    MacStickyConfigurationRow(
                        configuration: configuration,
                        onShowHide: {
                            configuration.isVisible
                                ? coordinator.hideWindow(id: configuration.id)
                                : coordinator.showWindow(for: configuration.id)
                        },
                        onCollapse: { coordinator.setCollapsed(!configuration.isCollapsed, id: configuration.id) },
                        onEdit: { editingConfiguration = configuration },
                        onDelete: { coordinator.removeConfiguration(id: configuration.id) }
                    )
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $editingConfiguration) { configuration in
            MacStickyConfigurationEditor(configuration: configuration) { title, paper, floating, opacity in
                coordinator.updateConfiguration(configuration.id, title: title, paper: paper, isFloating: floating, opacity: opacity)
            }
        }
        .confirmationDialog("新建象限便笺", isPresented: $showingCategoryPicker, titleVisibility: .visible) {
            ForEach(TaskCategory.allCases.filter { $0 != .all && $0 != .completed }) { category in
                Button(category.displayName) { coordinator.pinCategory(category) }
            }
            Button("全部未完成任务") { coordinator.pinCategory(.all) }
            Button("取消", role: .cancel) { }
        }
    }
}

private struct MacStickyConfigurationRow: View {
    let configuration: MacStickyConfiguration
    let onShowHide: () -> Void
    let onCollapse: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(configuration.paper.color)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(configuration.title).fontWeight(.medium)
                Text(sourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onShowHide) {
                Label(configuration.isVisible ? "隐藏" : "展示", systemImage: configuration.isVisible ? "eye.slash" : "eye")
            }
            Button(action: onCollapse) {
                Label(configuration.isCollapsed ? "展开" : "收起", systemImage: configuration.isCollapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            Button("编辑", systemImage: "slider.horizontal.3", action: onEdit)
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .help("删除便笺配置")
        }
        .padding(.vertical, 4)
    }

    private var sourceDescription: String {
        switch configuration.source {
        case .selectedTaskIDs(let ids): "手选任务 · \(ids.count) 项"
        case .category(let category): "动态象限 · \(category.displayName)"
        }
    }
}

private struct MacStickyConfigurationEditor: View {
    @Environment(\.dismiss) private var dismiss
    let configuration: MacStickyConfiguration
    let onSave: (String, MacStickyPaper, Bool, Double) -> Void
    @State private var title: String
    @State private var paper: MacStickyPaper
    @State private var isFloating: Bool
    @State private var opacity: Double

    init(configuration: MacStickyConfiguration, onSave: @escaping (String, MacStickyPaper, Bool, Double) -> Void) {
        self.configuration = configuration
        self.onSave = onSave
        _title = State(initialValue: configuration.title)
        _paper = State(initialValue: configuration.paper)
        _isFloating = State(initialValue: configuration.isFloating)
        _opacity = State(initialValue: configuration.opacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑便笺").font(.title2.weight(.semibold))
            TextField("名称", text: $title)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                ForEach(MacStickyPaper.allCases) { choice in
                    Button { paper = choice } label: {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(choice.color)
                            .frame(width: 36, height: 28)
                            .overlay {
                                if paper == choice { Image(systemName: "checkmark").foregroundStyle(.primary) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.title)
                }
            }
            Toggle("保持在其他窗口上方", isOn: $isFloating)
            VStack(alignment: .leading) {
                Text("纸张透明度 \(Int(opacity * 100))%")
                Slider(value: $opacity, in: 0.65...1)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    onSave(title, paper, isFloating, opacity)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 360)
    }
}

struct MacStickyNoteView: View {
    let configurationID: UUID
    @Environment(MacStickyCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuadrantTask.updatedAt, order: .reverse) private var allTasks: [QuadrantTask]
    @State private var showingTaskPicker = false
    @State private var newTaskTitle = ""

    init(configurationID: UUID) {
        self.configurationID = configurationID
    }

    var body: some View {
        if let configuration = coordinator.configurations.first(where: { $0.id == configurationID }) {
            VStack(spacing: 0) {
                MacStickyTitleBar(configuration: configuration, onClose: { coordinator.hideWindow(id: configurationID) })
                if !configuration.isCollapsed {
                    switch configuration.source {
                    case .selectedTaskIDs:
                        taskList(configuration, now: .now)
                    case .category:
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            taskList(configuration, now: timeline.date)
                        }
                    }
                }
            }
            .foregroundStyle(MacStickyPalette.ink)
            .background(configuration.paper.color.opacity(configuration.opacity))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.12), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.13), radius: 8, x: 0, y: 3)
            .padding(1)
            .sheet(isPresented: $showingTaskPicker) {
                MacStickyTaskPickerView(excludedIDs: referencedIDs(configuration)) { task in
                    coordinator.addTaskReference(task.id, to: configurationID)
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func taskList(_ configuration: MacStickyConfiguration, now: Date) -> some View {
        let tasks = coordinator.visibleTasks(from: configuration.source, in: allTasks, now: now)
        VStack(spacing: 0) {
            if tasks.isEmpty {
                Text("没有显示的任务")
                    .font(.callout)
                    .foregroundStyle(MacStickyPalette.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(tasks, id: \.id) { task in
                            MacStickyTaskRow(task: task,
                                onToggle: { _ = coordinator.taskStore.toggleTask(task) },
                                onRemove: { coordinator.removeTaskReference(task.id, from: configurationID) },
                                onOpen: { coordinator.openTaskInMainApp(task.id) })
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            if case .selectedTaskIDs = configuration.source {
                HStack(spacing: 6) {
                    TextField("新任务…", text: $newTaskTitle)
                        .textFieldStyle(.plain)
                        .foregroundStyle(MacStickyPalette.ink)
                        .onSubmit(createTask)
                    Button(action: createTask) { Image(systemName: "plus.circle.fill") }
                        .buttonStyle(.plain)
                        .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { showingTaskPicker = true } label: { Image(systemName: "list.bullet") }
                        .buttonStyle(.plain)
                        .help("添加现有任务")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.black.opacity(0.045))
            }
            if let error = coordinator.persistenceError ?? coordinator.taskStore.lastErrorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 9)
                    .padding(.bottom, 5)
            }
        }
    }

    private func referencedIDs(_ configuration: MacStickyConfiguration) -> Set<UUID> {
        guard case .selectedTaskIDs(let ids) = configuration.source else { return [] }
        return Set(ids)
    }

    private func createTask() {
        guard coordinator.createTask(title: newTaskTitle, for: configurationID) else { return }
        newTaskTitle = ""
    }
}

private struct MacStickyTitleBar: View {
    let configuration: MacStickyConfiguration
    let onClose: () -> Void
    @Environment(MacStickyCoordinator.self) private var coordinator

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onClose) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.82, green: 0.31, blue: 0.27))
                    .frame(width: 11, height: 11)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.13), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
            .help("隐藏便笺")
            .accessibilityLabel("隐藏便笺")
            Spacer(minLength: 0)
            Color.clear.frame(width: 11, height: 11)
        }
        .overlay {
            Text(configuration.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MacStickyPalette.ink)
                .lineLimit(1)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { coordinator.setCollapsed(!configuration.isCollapsed, id: configuration.id) }
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(Color(red: 0.78, green: 0.91, blue: 0.92))
        .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.09)).frame(height: 0.5) }
    }
}

private struct MacStickyTaskRow: View {
    let task: QuadrantTask
    let onToggle: () -> Void
    let onRemove: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(MacStickyPalette.ink.opacity(task.isCompleted ? 0.58 : 0.86))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "重新打开任务：\(task.title)" : "完成任务：\(task.title)")
            Text(task.title)
                .lineLimit(2)
                .strikethrough(task.isCompleted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: onOpen)
            Menu {
                Button("在主窗口中打开", systemImage: "arrow.up.forward.app", action: onOpen)
                Button("从此便笺移除", systemImage: "minus.circle", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(MacStickyPalette.ink.opacity(0.68))
                    .frame(width: 22, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("任务操作：\(task.title)")
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 4)
        .frame(minHeight: 32)
        .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.07)).frame(height: 0.5) }
    }
}

private struct MacStickyTaskPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QuadrantTask.updatedAt, order: .reverse) private var tasks: [QuadrantTask]
    let excludedIDs: Set<UUID>
    let onSelect: (QuadrantTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("添加现有任务").font(.headline).padding(.horizontal)
            List(tasks.filter { !excludedIDs.contains($0.id) }, id: \.id) { task in
                Button {
                    onSelect(task)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: task.isCompleted ? "checkmark.circle" : "circle")
                        Text(task.title).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 320, height: 380)
    }
}

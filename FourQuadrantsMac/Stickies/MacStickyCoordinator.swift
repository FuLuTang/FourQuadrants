import AppKit
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class MacStickyCoordinator {
    static let persistenceKey = "FourQuadrants.macStickies.configurations.v1"

    let container: ModelContainer
    let taskStore: TaskStore
    let defaults: UserDefaults
    private(set) var configurations: [MacStickyConfiguration] = []
    private(set) var persistenceError: String?
    @ObservationIgnored private var hasUnreadableStoredConfigurations = false
    @ObservationIgnored private var windows: [UUID: MacStickyWindowController] = [:]

    init(container: ModelContainer, taskStore: TaskStore, defaults: UserDefaults = .standard) {
        self.container = container
        self.taskStore = taskStore
        self.defaults = defaults
        do {
            configurations = try Self.loadConfigurations(from: defaults)
        } catch {
            hasUnreadableStoredConfigurations = true
            persistenceError = "无法读取便笺配置：\(error.localizedDescription)"
        }
    }

    func pinTasks(_ ids: [UUID], title: String) {
        let config = MacStickyConfiguration(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "便笺" : title,
            source: .selectedTaskIDs(Self.unique(ids)),
            isVisible: true
        )
        configurations.append(config)
        persist()
        showWindow(for: config.id)
    }

    func pinCategory(_ category: TaskCategory) {
        let config = MacStickyConfiguration(title: category.displayName, source: .category(category), isVisible: true)
        configurations.append(config)
        persist()
        showWindow(for: config.id)
    }

    func createEmptyNote(title: String = "便笺") {
        configurations.append(MacStickyConfiguration(title: title, source: .selectedTaskIDs([])))
        persist()
    }

    func restoreWindows() {
        for configuration in configurations where configuration.isVisible {
            showWindow(for: configuration.id)
        }
    }

    func closeAllWindows() {
        for id in Array(windows.keys) {
            hideWindow(id: id)
            windows[id]?.closePermanently()
        }
        windows.removeAll()
    }

    func showWindow(for id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        var configuration = configurations[index]
        configuration.isVisible = true
        configurations[index] = configuration
        persist()
        let controller = windows[id] ?? makeWindow(for: configuration)
        windows[id] = controller
        controller.show()
    }

    func hideWindow(id: UUID) {
        windows[id]?.hide()
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].isVisible = false
        persist()
    }

    func removeConfiguration(id: UUID) {
        guard !hasUnreadableStoredConfigurations else { return }
        let previous = configurations
        configurations.removeAll { $0.id == id }
        persist()
        guard persistenceError == nil else {
            configurations = previous
            return
        }
        windows[id]?.closePermanently()
        windows[id] = nil
    }

    func updateConfiguration(_ id: UUID, title: String, paper: MacStickyPaper, isFloating: Bool, opacity: Double) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "便笺" : title
        configurations[index].paper = paper
        configurations[index].isFloating = isFloating
        configurations[index].opacity = min(max(opacity, 0.65), 1)
        windows[id]?.apply(configurations[index])
        persist()
    }

    func setCollapsed(_ collapsed: Bool, id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].isCollapsed = collapsed
        windows[id]?.setCollapsed(collapsed)
        persist()
    }

    func addTaskReference(_ taskID: UUID, to id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              case .selectedTaskIDs(var ids) = configurations[index].source else { return }
        if !ids.contains(taskID) { ids.append(taskID) }
        configurations[index].source = .selectedTaskIDs(ids)
        persist()
    }

    func removeTaskReference(_ taskID: UUID, from id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              case .selectedTaskIDs(let ids) = configurations[index].source else { return }
        configurations[index].source = .selectedTaskIDs(ids.filter { $0 != taskID })
        persist()
    }

    func replaceTaskReferences(_ ids: [UUID], for id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].source = .selectedTaskIDs(Self.unique(ids))
        persist()
    }

    @discardableResult
    func createTask(title: String, for id: UUID) -> Bool {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty,
              let configuration = configurations.first(where: { $0.id == id }) else { return false }
        let category: TaskCategory
        if case .category(let selectedCategory) = configuration.source {
            category = selectedCategory == .completed ? .notImportantAndNotUrgent : selectedCategory
        } else {
            category = .notImportantAndNotUrgent
        }
        let important = category == .importantAndUrgent || category == .importantButNotUrgent
        let urgent = category == .importantAndUrgent || category == .urgentButNotImportant
        let taskID = UUID()
        guard taskStore.addTask(id: taskID, title: cleanedTitle, importance: important ? .high : .normal, isUrgent: urgent,
                                isTop: false, urgentThresholdDays: nil) else { return false }
        if case .selectedTaskIDs = configuration.source {
            addTaskReference(taskID, to: id)
        } else if case .category(.completed) = configuration.source,
                  let task = try? container.mainContext.fetch(FetchDescriptor<QuadrantTask>(predicate: #Predicate { $0.id == taskID })).first {
            _ = taskStore.toggleTask(task)
        }
        return true
    }

    func recordFrame(_ frame: NSRect, id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].frame = MacStickyWindowFrame(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
        persist()
    }

    func openTaskInMainApp(_ id: UUID) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .macShowTask, object: id)
    }

    func visibleTasks(from source: MacStickySource, in tasks: [QuadrantTask], now: Date) -> [QuadrantTask] {
        switch source {
        case .selectedTaskIDs(let ids):
            let selected = Set(ids)
            return taskStore.sortTasks(tasks.filter { selected.contains($0.id) }, by: .intelligence)
        case .category(let category):
            return taskStore.filteredTasks(tasks, in: category, now: now)
        }
    }

    private func makeWindow(for configuration: MacStickyConfiguration) -> MacStickyWindowController {
        MacStickyWindowController(configuration: configuration, coordinator: self, container: container, taskStore: taskStore)
    }

    private func persist() {
        guard !hasUnreadableStoredConfigurations else { return }
        do {
            let data = try Self.encode(configurations)
            let previousValue = defaults.object(forKey: Self.persistenceKey)
            defaults.set(data, forKey: Self.persistenceKey)
            guard defaults.data(forKey: Self.persistenceKey) == data else {
                if let previousValue {
                    defaults.set(previousValue, forKey: Self.persistenceKey)
                } else {
                    defaults.removeObject(forKey: Self.persistenceKey)
                }
                throw MacStickyPersistenceError.writeVerificationFailed
            }
            persistenceError = nil
        } catch {
            persistenceError = "无法保存便笺配置：\(error.localizedDescription)"
        }
    }

    static func loadConfigurations(from defaults: UserDefaults) throws -> [MacStickyConfiguration] {
        guard let storedValue = defaults.object(forKey: persistenceKey) else { return [] }
        guard let data = storedValue as? Data else { throw MacStickyPersistenceError.invalidStoredValue }
        return try JSONDecoder().decode([MacStickyConfiguration].self, from: data)
    }

    static func encode(_ configurations: [MacStickyConfiguration]) throws -> Data {
        try JSONEncoder().encode(configurations)
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}

private enum MacStickyPersistenceError: LocalizedError {
    case writeVerificationFailed
    case invalidStoredValue
    var errorDescription: String? {
        switch self {
        case .writeVerificationFailed: "系统未能确认便笺配置已写入。"
        case .invalidStoredValue: "便笺配置的存储格式无法识别。原始数据已保留。"
        }
    }
}

@MainActor
private final class MacStickyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class MacStickyWindowController: NSObject, NSWindowDelegate {
    private let window: MacStickyWindow
    private weak var coordinator: MacStickyCoordinator?
    private var configurationID: UUID
    private var expandedHeight: CGFloat

    init(configuration: MacStickyConfiguration, coordinator: MacStickyCoordinator, container: ModelContainer, taskStore: TaskStore) {
        self.configurationID = configuration.id
        self.coordinator = coordinator
        self.expandedHeight = CGFloat(configuration.frame.height)
        let frame = NSRect(x: configuration.frame.x, y: configuration.frame.y, width: configuration.frame.width, height: configuration.isCollapsed ? 25 : configuration.frame.height)
        window = MacStickyWindow(contentRect: frame, styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        super.init()
        window.delegate = self
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView = NSHostingView(rootView: MacStickyNoteView(configurationID: configuration.id)
            .modelContainer(container)
            .environment(coordinator))
        apply(configuration)
    }

    func show() {
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    func hide() { window.orderOut(nil) }
    func closePermanently() {
        window.delegate = nil
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }

    func apply(_ configuration: MacStickyConfiguration) {
        window.level = configuration.isFloating ? .floating : .normal
        window.alphaValue = 1
    }

    func setCollapsed(_ collapsed: Bool) {
        var frame = window.frame
        if collapsed {
            expandedHeight = frame.height
            frame.origin.y += frame.height - 25
            frame.size.height = 25
        } else {
            frame.origin.y -= max(expandedHeight - frame.height, 0)
            frame.size.height = max(expandedHeight, 190)
        }
        window.setFrame(frame, display: true, animate: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        coordinator?.hideWindow(id: configurationID)
        return false
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    private func saveFrame() {
        guard let coordinator else { return }
        var frame = window.frame
        if let configuration = coordinator.configurations.first(where: { $0.id == configurationID }), configuration.isCollapsed {
            frame.size.height = expandedHeight
            frame.origin.y -= expandedHeight - window.frame.height
        }
        coordinator.recordFrame(frame, id: configurationID)
    }
}

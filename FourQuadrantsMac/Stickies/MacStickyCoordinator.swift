import AppKit
import Observation
import SwiftData

/// 只负责便笺配置与对外接口：窗口生命周期交给 `MacStickyPanelController`，内容交给 SwiftUI。
@MainActor
@Observable
final class MacStickyCoordinator {
    static let persistenceKey = MacStickyConfigurationStore.key

    let container: ModelContainer
    let taskStore: TaskStore
    private(set) var persistenceError: String?
    /// Routes "show this task" requests to the app runtime without depending on its type.
    @ObservationIgnored var onOpenTask: ((UUID) -> Void)?
    @ObservationIgnored private let store: MacStickyConfigurationStore
    @ObservationIgnored private var storedConfigurations: [MacStickyConfiguration] = []
    @ObservationIgnored private var windows: [UUID: MacStickyPanelController] = [:]
    @ObservationIgnored nonisolated(unsafe) private var terminationObserver: NSObjectProtocol?

    /// 拖动、缩放时位置只改内存，不触发界面刷新；其余修改会通知观察者。
    private(set) var configurations: [MacStickyConfiguration] {
        get {
            access(keyPath: \.configurations)
            return storedConfigurations
        }
        set {
            withMutation(keyPath: \.configurations) { storedConfigurations = newValue }
        }
    }

    init(container: ModelContainer, taskStore: TaskStore, defaults: UserDefaults = .standard, saveDebounce: TimeInterval = 0.4) {
        self.container = container
        self.taskStore = taskStore
        store = MacStickyConfigurationStore(defaults: defaults, debounceInterval: saveDebounce)
        storedConfigurations = store.load()
        persistenceError = store.lastError
        store.onErrorChange = { [weak self] message in self?.persistenceError = message }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushPendingChanges() }
        }
    }

    deinit {
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
    }

    @discardableResult
    func createNote(source: MacStickySource, frame: MacStickyWindowFrame? = nil) -> UUID {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let configuration = MacStickyConfiguration(
            source: source,
            frame: frame ?? MacStickyLayout.defaultFrame(for: source, index: configurations.count, in: screenFrame),
            isVisible: true
        )
        configurations.append(configuration)
        save()
        showWindow(for: configuration.id)
        return configuration.id
    }

    func restoreWindows() {
        for configuration in configurations where configuration.isVisible {
            showWindow(for: configuration.id)
        }
    }

    /// 退出应用时关闭窗口；不改变配置里的可见性，下次启动会恢复。
    func closeAllWindows() {
        flushPendingChanges()
        for controller in windows.values {
            controller.close()
        }
        windows.removeAll()
    }

    func showWindow(for id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].isVisible = true
        save()
        let controller = windows[id] ?? makeWindow(for: configurations[index])
        windows[id] = controller
        controller.show()
    }

    func hideWindow(id: UUID) {
        windows[id]?.hide()
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].isVisible = false
        save()
    }

    func removeConfiguration(id: UUID) {
        guard !store.isReadOnly else { return }
        let previous = configurations
        configurations.removeAll { $0.id == id }
        save()
        guard persistenceError == nil else {
            configurations = previous
            return
        }
        windows[id]?.close()
        windows[id] = nil
    }

    func setSource(_ source: MacStickySource, for id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].source = source
        if case .combined = source {
            configurations[index].frame = configurations[index].frame.widened(toAtLeast: MacStickyLayout.combinedMinimumWidth)
        }
        windows[id]?.apply(configurations[index])
        save()
    }

    func setFloating(_ isFloating: Bool, id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].isFloating = isFloating
        windows[id]?.apply(configurations[index])
        save()
    }

    func setShowDetails(_ showDetails: Bool, id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].showDetails = showDetails
        save()
    }

    func setCollapsed(_ collapsed: Bool, id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].isCollapsed = collapsed
        windows[id]?.apply(configurations[index], animated: true)
        save()
    }

    /// 窗口被拖动或缩放后调用：只更新内存并防抖写盘。
    func recordWindowFrame(_ window: NSRect, id: UUID) {
        guard let index = storedConfigurations.firstIndex(where: { $0.id == id }) else { return }
        let current = storedConfigurations[index]
        let updated = current.frame.updated(
            fromWindow: MacStickyWindowFrame(x: window.minX, y: window.minY, width: window.width, height: window.height),
            isCollapsed: current.isCollapsed
        )
        guard updated != current.frame else { return }
        storedConfigurations[index].frame = updated
        save(debounced: true)
    }

    /// 立即写入尚未落盘的位置变化。
    func flushPendingChanges() {
        store.flush()
    }

    func openTaskInMainApp(_ id: UUID) {
        onOpenTask?(id)
    }

    func visibleTasks(from source: MacStickySource, in tasks: [QuadrantTask], now: Date) -> [QuadrantTask] {
        switch source {
        case .category(let category):
            return taskStore.filteredTasks(tasks, in: category, now: now)
        case .combined:
            return taskStore.filteredTasks(tasks, in: .all, now: now)
        case .smart, .selectedTaskIDs:
            return TaskOrdering.recommended(tasks.filter { !$0.isCompleted }, limit: 8)
        }
    }

    private func makeWindow(for configuration: MacStickyConfiguration) -> MacStickyPanelController {
        MacStickyPanelController(configuration: configuration, coordinator: self, container: container)
    }

    private func save(debounced: Bool = false) {
        store.save(storedConfigurations, debounced: debounced)
        persistenceError = store.lastError
    }

    static func loadConfigurations(from defaults: UserDefaults) throws -> [MacStickyConfiguration] {
        try MacStickyConfigurationStore.load(from: defaults)
    }

    static func encode(_ configurations: [MacStickyConfiguration]) throws -> Data {
        try MacStickyConfigurationStore.encode(configurations)
    }

    #if DEBUG
    /// 视觉验收用：清空已有便笺，创建单象限、四合一、收起态与智能排列各一张。
    func createPreviewNotes() {
        for configuration in configurations { removeConfiguration(id: configuration.id) }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        func frame(_ source: MacStickySource, column: Double) -> MacStickyWindowFrame {
            var frame = MacStickyLayout.defaultFrame(for: source, index: 0, in: screen)
            frame.x += column
            return frame
        }
        createNote(source: .category(.importantAndUrgent), frame: frame(.category(.importantAndUrgent), column: 0))
        createNote(source: .combined, frame: frame(.combined, column: 260))
        let collapsed = createNote(source: .category(.importantButNotUrgent), frame: frame(.category(.importantButNotUrgent), column: 650))
        setCollapsed(true, id: collapsed)
        createNote(source: .smart, frame: frame(.smart, column: 910))
    }
    #endif
}

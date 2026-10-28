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
    /// Routes "show this task" requests to the app runtime without depending on its type.
    @ObservationIgnored var onOpenTask: ((UUID) -> Void)?
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

    @discardableResult
    func createNote(source: MacStickySource) -> UUID {
        let paper: MacStickyPaper
        if case .category(let category) = source {
            paper = .default(for: category)
        } else {
            paper = .yellow
        }
        var frame = MacStickyWindowFrame.initial
        if case .combined = source {
            frame.width = max(frame.width, Double(Self.combinedMinimumWidth))
        }
        let configuration = MacStickyConfiguration(
            title: source.title,
            source: source,
            paper: paper,
            frame: frame,
            isVisible: true
        )
        configurations.append(configuration)
        persist()
        showWindow(for: configuration.id)
        return configuration.id
    }

    func restoreWindows() {
        for configuration in configurations where configuration.isVisible {
            showWindow(for: configuration.id)
        }
    }

    func closeAllWindows() {
        for id in Array(windows.keys) {
            guard let controller = windows[id] else { continue }
            controller.schedulePermanentClose()
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
        windows[id]?.schedulePermanentClose()
        windows[id] = nil
    }

    func updateConfiguration(_ id: UUID, title: String, paper: MacStickyPaper, isFloating: Bool, opacity: Double, showDetails: Bool? = nil) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        configurations[index].title = trimmedTitle.isEmpty ? "便笺" : trimmedTitle
        configurations[index].paper = paper
        configurations[index].isFloating = isFloating
        configurations[index].opacity = min(max(opacity, 0.65), 1)
        if let showDetails { configurations[index].showDetails = showDetails }
        windows[id]?.apply(configurations[index])
        persist()
    }

    func updateSource(_ source: MacStickySource, for id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].source = source
        configurations[index].title = source.title
        if case .combined = source {
            if let controller = windows[id] {
                controller.ensureMinimumExpandedWidth(Self.combinedMinimumWidth, isCollapsed: configurations[index].isCollapsed)
            } else if configurations[index].frame.width < Double(Self.combinedMinimumWidth) {
                let widthDelta = Double(Self.combinedMinimumWidth) - configurations[index].frame.width
                configurations[index].frame.x -= widthDelta / 2
                configurations[index].frame.width = Double(Self.combinedMinimumWidth)
            }
        }
        persist()
    }

    func updatePreferences(id: UUID, isFloating: Bool, showDetails: Bool) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].isFloating = isFloating
        configurations[index].showDetails = showDetails
        windows[id]?.apply(configurations[index])
        persist()
    }

    func setCollapsed(_ collapsed: Bool, id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].isCollapsed = collapsed
        windows[id]?.setCollapsed(collapsed)
        persist()
    }

    func recordFrame(_ frame: NSRect, id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].frame = MacStickyWindowFrame(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
        persist()
    }

    func openTaskInMainApp(_ id: UUID) {
        onOpenTask?(id)
    }

    func visibleTasks(from source: MacStickySource, in tasks: [QuadrantTask], now: Date) -> [QuadrantTask] {
        switch source {
        case .selectedTaskIDs(let ids):
            let selected = Set(ids)
            return taskStore.sortTasks(tasks.filter { selected.contains($0.id) }, by: .intelligence)
        case .category(let category):
            return taskStore.filteredTasks(tasks, in: category, now: now)
        case .combined:
            return taskStore.filteredTasks(tasks, in: .all, now: now)
        case .smart:
            let openTasks = tasks.filter { !$0.isCompleted }
            return TaskOrdering.recommended(openTasks, limit: 8)
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

    fileprivate static let collapsedWindowHeight: CGFloat = 32
    fileprivate static let combinedMinimumWidth: CGFloat = 420
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
    private var expandedFrame: NSRect
    private var isFinishingClose = false
    private var isChangingCollapsedState = false

    init(configuration: MacStickyConfiguration, coordinator: MacStickyCoordinator, container: ModelContainer, taskStore: TaskStore) {
        self.configurationID = configuration.id
        self.coordinator = coordinator
        self.expandedFrame = NSRect(x: configuration.frame.x, y: configuration.frame.y, width: configuration.frame.width, height: configuration.frame.height)
        var frame = expandedFrame
        if configuration.isCollapsed {
            let compact = configuration.frame.collapsed(to: Double(MacStickyCoordinator.collapsedWindowHeight))
            frame = NSRect(x: compact.x, y: compact.y, width: compact.width, height: compact.height)
        }
        window = MacStickyWindow(contentRect: frame, styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        super.init()
        window.isReleasedWhenClosed = false
        if configuration.isCollapsed {
            window.styleMask.remove(.resizable)
        }
        window.delegate = self
        window.isMovableByWindowBackground = false
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
    func schedulePermanentClose() {
        guard !isFinishingClose else { return }
        isFinishingClose = true
        window.orderOut(nil)
        DispatchQueue.main.async { [self] in
            window.delegate = nil
            window.contentView = nil
            window.close()
        }
    }

    func apply(_ configuration: MacStickyConfiguration) {
        guard !isFinishingClose else { return }
        window.level = configuration.isFloating ? .floating : .normal
        window.alphaValue = CGFloat(configuration.opacity)
    }

    func setCollapsed(_ collapsed: Bool) {
        guard !isFinishingClose else { return }
        var frame = window.frame
        if collapsed {
            expandedFrame = frame
            let compact = MacStickyWindowFrame(
                x: expandedFrame.minX,
                y: expandedFrame.minY,
                width: expandedFrame.width,
                height: expandedFrame.height
            ).collapsed(to: Double(MacStickyCoordinator.collapsedWindowHeight))
            frame = NSRect(x: compact.x, y: compact.y, width: compact.width, height: compact.height)
            window.styleMask.remove(.resizable)
        } else {
            frame = expandedFrame
            window.styleMask.insert(.resizable)
        }
        isChangingCollapsedState = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isChangingCollapsedState = false
                self.coordinator?.recordFrame(self.expandedFrame, id: self.configurationID)
            }
        }
    }

    func ensureMinimumExpandedWidth(_ minimumWidth: CGFloat, isCollapsed: Bool) {
        guard !isFinishingClose, expandedFrame.width < minimumWidth else { return }
        if isCollapsed {
            expandedFrame.origin.x = window.frame.minX
        } else {
            expandedFrame.origin.x = expandedFrame.midX - minimumWidth / 2
        }
        expandedFrame.size.width = minimumWidth
        if !isCollapsed {
            window.setFrame(expandedFrame, display: true, animate: false)
        }
        coordinator?.recordFrame(expandedFrame, id: configurationID)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        coordinator?.hideWindow(id: configurationID)
        return false
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    private func saveFrame() {
        guard !isFinishingClose, !isChangingCollapsedState, let coordinator else { return }
        let frame = window.frame
        if let configuration = coordinator.configurations.first(where: { $0.id == configurationID }), configuration.isCollapsed {
            let dx = frame.minX - expandedFrame.minX
            let dy = frame.minY - (expandedFrame.maxY - MacStickyCoordinator.collapsedWindowHeight)
            expandedFrame.origin.x += dx
            expandedFrame.origin.y += dy
        } else {
            expandedFrame = frame
        }
        coordinator.recordFrame(expandedFrame, id: configurationID)
    }

}

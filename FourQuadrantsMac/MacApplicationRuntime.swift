import Foundation
import Observation
import SwiftData

/// A navigation request waiting for the main workspace to appear.
enum MacRoute: Equatable {
    case showTask(UUID)
    case newTask
}

/// Owns one data session for every Mac window. Window configuration and task
/// persistence have separate lifetimes, but all views use the same TaskStore.
@MainActor
@Observable
final class MacApplicationRuntime {
    private(set) var data: AppDataController?
    private(set) var stickies: MacStickyCoordinator?
    private(set) var initializationError: String?
    /// Survives the main window being closed or not yet created; the workspace
    /// consumes it when it appears. The latest request wins.
    private(set) var pendingRoute: MacRoute?
    let isPreview: Bool
    @ObservationIgnored private var mainWindowOpener: (() -> Void)?
    private var didRestoreWindows = false

    init() {
        let process = ProcessInfo.processInfo
        isPreview = process.arguments.contains("--preview-data")
            || process.environment["XCTestConfigurationFilePath"] != nil
            || process.environment["XCTestBundlePath"] != nil
        if isPreview {
            do {
                let container = try PersistenceController.inMemoryContainer()
                try MacPreviewData.populate(container.mainContext)
                data = AppDataController(container: container, configureSync: false)
            } catch {
                initializationError = error.localizedDescription
            }
        } else {
            data = AppDataController()
        }
        connectWindows()
    }

    func retry() {
        data?.retry()
        connectWindows()
    }

    func reset() {
        stickies?.closeAllWindows()
        stickies = nil
        data?.resetLocalData()
        connectWindows()
    }

    func restoreWindowsIfNeeded() {
        guard !didRestoreWindows else { return }
        didRestoreWindows = true
        #if DEBUG
        if isPreview, ProcessInfo.processInfo.arguments.contains("--preview-stickies") {
            stickies?.createPreviewNotes()
            return
        }
        #endif
        stickies?.restoreWindows()
        if !isPreview { _ = AppLifecycleManager.shared.performUpdateIfNeeded() }
    }

    /// Registered by an always-alive SwiftUI view that has `openWindow`, so
    /// AppKit callers (sticky notes) can bring the main window back.
    func registerMainWindowOpener(_ opener: @escaping () -> Void) {
        mainWindowOpener = opener
    }

    func requestNewTask() {
        request(.newTask)
    }

    func requestShowTask(_ id: UUID) {
        request(.showTask(id))
    }

    /// Handles `fourquadrants://task/<uuid>`; returns whether the URL was recognized.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == "fourquadrants", url.host == "task",
              let id = UUID(uuidString: url.lastPathComponent) else { return false }
        requestShowTask(id)
        return true
    }

    func consumePendingRoute() -> MacRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func reconnectWindows() {
        connectWindows()
    }

    private func request(_ route: MacRoute) {
        pendingRoute = route
        mainWindowOpener?()
    }

    private func connectWindows() {
        guard let data, case .ready(let session) = data.state else { return }
        let defaults = isPreview
            ? (UserDefaults(suiteName: "fulu.FourQuadrantsMac.preview") ?? .standard)
            : .standard
        let coordinator = MacStickyCoordinator(container: session.container, taskStore: session.taskStore, defaults: defaults)
        coordinator.onOpenTask = { [weak self] id in self?.requestShowTask(id) }
        stickies = coordinator
        didRestoreWindows = false
    }
}

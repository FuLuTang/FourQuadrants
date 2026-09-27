import Foundation
import Observation
import SwiftData

/// Owns one data session for every Mac window. Window configuration and task
/// persistence have separate lifetimes, but all views use the same TaskStore.
@MainActor
@Observable
final class MacApplicationRuntime {
    private(set) var data: AppDataController?
    private(set) var stickies: MacStickyCoordinator?
    private(set) var initializationError: String?
    let isPreview: Bool
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
        stickies?.restoreWindows()
        if !isPreview { _ = AppLifecycleManager.shared.performUpdateIfNeeded() }
    }

    private func connectWindows() {
        guard let data, case .ready(let session) = data.state else { return }
        let defaults = isPreview
            ? (UserDefaults(suiteName: "fulu.FourQuadrantsMac.preview") ?? .standard)
            : .standard
        stickies = MacStickyCoordinator(container: session.container, taskStore: session.taskStore, defaults: defaults)
        didRestoreWindows = false
    }
}

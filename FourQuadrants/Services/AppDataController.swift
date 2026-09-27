import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppDataController {
    enum State {
        case loading
        case ready(AppDataSession)
        case recoveryRequired(PersistenceError)
    }

    struct AppDataSession {
        let container: ModelContainer
        let taskStore: TaskStore
    }

    private let persistence: PersistenceController
    var state: State = .loading

    convenience init() {
        self.init(persistence: PersistenceController())
    }

    init(persistence: PersistenceController) {
        self.persistence = persistence
        openStore()
    }

    /// Supplies an isolated store for previews and UI validation. Disabling sync
    /// keeps sample mutations away from the authenticated Microsoft account.
    init(container: ModelContainer, configureSync: Bool) {
        persistence = PersistenceController()
        let taskStore = TaskStore(modelContext: container.mainContext)
        if configureSync {
            SyncService.shared.configure(modelContext: container.mainContext, taskStore: taskStore)
        }
        state = .ready(AppDataSession(container: container, taskStore: taskStore))
    }

    func retry() {
        openStore()
    }

    func resetLocalData() {
        state = .loading
        do {
            try persistence.resetStore()
            openStore()
        } catch let error as PersistenceError {
            state = .recoveryRequired(error)
        } catch {
            state = .recoveryRequired(.resetFailed(error.localizedDescription))
        }
    }

    private func openStore() {
        state = .loading
        do {
            let container = try persistence.makeContainer()
            let taskStore = TaskStore(modelContext: container.mainContext)
            SyncService.shared.configure(modelContext: container.mainContext, taskStore: taskStore)
            state = .ready(AppDataSession(container: container, taskStore: taskStore))
        } catch let error as PersistenceError {
            state = .recoveryRequired(error)
        } catch {
            state = .recoveryRequired(.storeCreationFailed(error.localizedDescription))
        }
    }
}

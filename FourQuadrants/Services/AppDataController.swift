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

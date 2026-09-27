import Foundation
import OSLog
import SwiftData

enum PersistenceError: LocalizedError, Equatable {
    case appGroupUnavailable(String)
    case storeCreationFailed(String)
    case resetFailed(String)

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "无法访问应用共享数据。请检查 App Group 配置。"
        case .storeCreationFailed:
            "无法打开本地任务数据。"
        case .resetFailed:
            "无法重置本地任务数据。"
        }
    }
}

struct PersistenceController {
    static let storeFilename = "FourQuadrants-v1.store"
    private static let logger = Logger(subsystem: "fulu.FourQuadrants", category: "Persistence")

    let appGroupIdentifier: String
    private let fileManager: FileManager

    init(appGroupIdentifier: String = PersistenceController.defaultAppGroupIdentifier, fileManager: FileManager = .default) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileManager = fileManager
    }

    static var defaultAppGroupIdentifier: String {
        #if DEBUG
        "group.fulu.FourQuadrants.dev"
        #else
        "group.fulu.FourQuadrants"
        #endif
    }

    func makeContainer() throws -> ModelContainer {
        let configuration = try makeStoreConfiguration()
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: AppSchemaV3.self),
                migrationPlan: AppMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            Self.logger.error("Unable to create SwiftData container: \(error.localizedDescription, privacy: .public)")
            throw PersistenceError.storeCreationFailed(error.localizedDescription)
        }
    }

    func makeStoreConfiguration() throws -> ModelConfiguration {
        let storeURL = try storeURL()
        return ModelConfiguration(
            "FourQuadrants-v1",
            schema: Schema(versionedSchema: AppSchemaV3.self),
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
    }

    func storeURL() throws -> URL {
        #if os(macOS)
        guard let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceError.storeCreationFailed("无法访问当前应用的 Application Support 目录。")
        }
        let directory = supportDirectory.appendingPathComponent("FourQuadrantsMac", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw PersistenceError.storeCreationFailed(error.localizedDescription)
        }
        return directory.appendingPathComponent(Self.storeFilename, isDirectory: false)
        #else
        guard let directory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw PersistenceError.appGroupUnavailable(appGroupIdentifier)
        }
        return directory.appendingPathComponent(Self.storeFilename, isDirectory: false)
        #endif
    }

    func resetStore() throws {
        let storeURL = try storeURL()
        let candidates = [storeURL, URL(fileURLWithPath: storeURL.path + "-wal"), URL(fileURLWithPath: storeURL.path + "-shm")]
        do {
            for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
                try fileManager.removeItem(at: candidate)
            }
        } catch {
            throw PersistenceError.resetFailed(error.localizedDescription)
        }
    }

    static func inMemoryContainer(allowsSave: Bool = true) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "FourQuadrants-tests",
            schema: Schema(versionedSchema: AppSchemaV3.self),
            isStoredInMemoryOnly: true,
            allowsSave: allowsSave,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV3.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
    }
}

import Foundation

/// 仅记录应用版本。SwiftData Schema 迁移由 `AppMigrationPlan` 管理。
final class AppLifecycleManager {
    static let shared = AppLifecycleManager()

    private enum Keys {
        static let lastAppVersion = "lastAppVersion"
        static let lastBuildNumber = "lastBuildNumber"
    }

    private let defaults = UserDefaults.standard
    private init() {}

    @discardableResult
    func performUpdateIfNeeded() -> Bool {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let lastVersion = defaults.string(forKey: Keys.lastAppVersion)
        defaults.set(version, forKey: Keys.lastAppVersion)
        defaults.set(build, forKey: Keys.lastBuildNumber)
        return lastVersion != version
    }
}

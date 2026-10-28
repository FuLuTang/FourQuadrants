import Foundation

enum MacStickyPersistenceError: LocalizedError {
    case writeVerificationFailed
    case invalidStoredValue
    var errorDescription: String? {
        switch self {
        case .writeVerificationFailed: "系统未能确认便笺配置已写入。"
        case .invalidStoredValue: "便笺配置的存储格式无法识别。原始数据已保留。"
        }
    }
}

/// 便笺配置的 UserDefaults 存储。结构性修改立即写入；拖动、缩放产生的位置变化防抖后再写，
/// 应用退出前由 `flush()` 保证落盘。
@MainActor
final class MacStickyConfigurationStore {
    static let key = "FourQuadrants.macStickies.configurations.v1"

    private let defaults: UserDefaults
    private let debounceInterval: TimeInterval
    private var pending: [MacStickyConfiguration]?
    private var scheduledWrite: Task<Void, Never>?
    /// 存档无法识别时为真：保留原始数据，不再覆盖。
    private(set) var isReadOnly = false
    private(set) var lastError: String?
    var onErrorChange: ((String?) -> Void)?

    init(defaults: UserDefaults, debounceInterval: TimeInterval) {
        self.defaults = defaults
        self.debounceInterval = debounceInterval
    }

    nonisolated static func load(from defaults: UserDefaults) throws -> [MacStickyConfiguration] {
        guard let storedValue = defaults.object(forKey: key) else { return [] }
        guard let data = storedValue as? Data else { throw MacStickyPersistenceError.invalidStoredValue }
        return try JSONDecoder().decode([MacStickyConfiguration].self, from: data)
    }

    nonisolated static func encode(_ configurations: [MacStickyConfiguration]) throws -> Data {
        try JSONEncoder().encode(configurations)
    }

    func load() -> [MacStickyConfiguration] {
        do {
            return try Self.load(from: defaults)
        } catch {
            isReadOnly = true
            report("无法读取便笺配置：\(error.localizedDescription)")
            return []
        }
    }

    /// 记录最新配置。`debounced` 为真时等待安静一段时间再写，期间的新修改会覆盖旧的。
    func save(_ configurations: [MacStickyConfiguration], debounced: Bool) {
        guard !isReadOnly else { return }
        pending = configurations
        scheduledWrite?.cancel()
        scheduledWrite = nil
        guard debounced else {
            flush()
            return
        }
        scheduledWrite = Task { [self, debounceInterval] in
            try? await Task.sleep(for: .seconds(debounceInterval))
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    /// 立即写入尚未落盘的配置。
    func flush() {
        scheduledWrite?.cancel()
        scheduledWrite = nil
        guard let configurations = pending else { return }
        pending = nil
        write(configurations)
    }

    private func write(_ configurations: [MacStickyConfiguration]) {
        do {
            let data = try Self.encode(configurations)
            let previousValue = defaults.object(forKey: Self.key)
            defaults.set(data, forKey: Self.key)
            guard defaults.data(forKey: Self.key) == data else {
                if let previousValue {
                    defaults.set(previousValue, forKey: Self.key)
                } else {
                    defaults.removeObject(forKey: Self.key)
                }
                throw MacStickyPersistenceError.writeVerificationFailed
            }
            report(nil)
        } catch {
            report("无法保存便笺配置：\(error.localizedDescription)")
        }
    }

    private func report(_ message: String?) {
        lastError = message
        onErrorChange?(message)
    }
}

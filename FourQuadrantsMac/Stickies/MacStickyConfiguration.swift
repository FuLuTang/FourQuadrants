import AppKit
import Foundation

enum MacStickySource: Codable, Equatable {
    /// 仅为兼容旧存档保留解码；显示时按智能排列处理。
    case selectedTaskIDs([UUID])
    case category(TaskCategory)
    case combined
    case smart

    private enum CodingKeys: String, CodingKey { case kind, taskIDs, category }
    private enum Kind: String, Codable { case selectedTaskIDs, category, combined, smart }

    var title: String {
        switch self {
        case .selectedTaskIDs, .smart: String(localized: "智能排列")
        case .category(let category): category.displayName
        case .combined: String(localized: "四合一")
        }
    }

    var displayTitle: String { title }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .selectedTaskIDs:
            self = .selectedTaskIDs(try container.decode([UUID].self, forKey: .taskIDs))
        case .category:
            self = .category(try container.decode(TaskCategory.self, forKey: .category))
        case .combined:
            self = .combined
        case .smart:
            self = .smart
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .selectedTaskIDs(let ids):
            try container.encode(Kind.selectedTaskIDs, forKey: .kind)
            try container.encode(ids, forKey: .taskIDs)
        case .category(let category):
            try container.encode(Kind.category, forKey: .kind)
            try container.encode(category, forKey: .category)
        case .combined:
            try container.encode(Kind.combined, forKey: .kind)
        case .smart:
            try container.encode(Kind.smart, forKey: .kind)
        }
    }

}

/// 便笺窗口的几何常量与默认值。
enum MacStickyLayout {
    /// 标题条高度，同时也是收起态窗口的高度。
    static let titleBarHeight: Double = 16
    /// 标题条两端控件向内缩进的距离，让方框点击区域避开窗口边缘的缩放热区。
    static let titleBarEdgeInset: Double = 8
    /// 收起/展开的窗口动画时长。
    static let collapseAnimationDuration: Double = 0.18
    static let minimumSize = (width: 160.0, height: 80.0)
    /// 四合一需要容纳 2×2 两列，窄于此宽度时向右扩展。
    static let combinedMinimumWidth: Double = 320

    static func defaultSize(for source: MacStickySource) -> (width: Double, height: Double) {
        if case .combined = source { return (360, 300) }
        return (220, 260)
    }

    /// 新建便笺的初始位置：可见区域左上角附近，按已有数量错开，避免完全重叠。
    static func defaultFrame(for source: MacStickySource, index: Int, in visibleFrame: NSRect) -> MacStickyWindowFrame {
        let size = defaultSize(for: source)
        let offset = Double(index % 8) * 24
        return MacStickyWindowFrame(
            x: visibleFrame.minX + 60 + offset,
            y: visibleFrame.maxY - 60 - offset - size.height,
            width: size.width,
            height: size.height
        )
    }
}

/// 展开态窗口框架（AppKit 坐标，原点在左下）。收起态窗口框架由它推导，不单独保存。
struct MacStickyWindowFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let initial = MacStickyWindowFrame(x: 180, y: 560, width: 220, height: 260)

    /// 收起：保持左边界、宽度与上边界，只让下边界上移。
    func collapsed(to height: Double) -> MacStickyWindowFrame {
        MacStickyWindowFrame(
            x: x,
            y: y + self.height - height,
            width: width,
            height: height
        )
    }

    /// 宽度不足时向右扩展，左边界不变。
    func widened(toAtLeast minimumWidth: Double) -> MacStickyWindowFrame {
        guard width < minimumWidth else { return self }
        var result = self
        result.width = minimumWidth
        return result
    }

    /// 当前应显示的窗口框架。
    func windowFrame(isCollapsed: Bool) -> MacStickyWindowFrame {
        isCollapsed ? collapsed(to: MacStickyLayout.titleBarHeight) : self
    }

    /// 窗口被拖动或缩放后，换算回展开态框架。收起态下以窗口上边界为准，保持展开高度。
    func updated(fromWindow window: MacStickyWindowFrame, isCollapsed: Bool) -> MacStickyWindowFrame {
        guard isCollapsed else { return window }
        return MacStickyWindowFrame(
            x: window.x,
            y: window.y + window.height - height,
            width: window.width,
            height: height
        )
    }
}

/// 一张浮窗便笺的持久化配置。旧存档里多余的字段（标题、纸张颜色、透明度）解码时忽略。
struct MacStickyConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    var source: MacStickySource
    /// 展开态框架；收起只改变窗口显示，不改变它（拖动收起态窗口会更新其位置）。
    var frame: MacStickyWindowFrame
    var isCollapsed: Bool
    var isVisible: Bool
    var isFloating: Bool
    var showDetails: Bool

    /// 显示名固定取自内容来源，供菜单与列表使用。
    var title: String { source.title }
    var displayTitle: String { source.displayTitle }

    private enum CodingKeys: String, CodingKey {
        case id, source, frame, isCollapsed, isVisible, isFloating, showDetails
    }

    init(
        id: UUID = UUID(),
        source: MacStickySource = .smart,
        frame: MacStickyWindowFrame = .initial,
        isCollapsed: Bool = false,
        isVisible: Bool = false,
        isFloating: Bool = true,
        showDetails: Bool = false
    ) {
        self.id = id
        self.source = source
        self.frame = frame
        self.isCollapsed = isCollapsed
        self.isVisible = isVisible
        self.isFloating = isFloating
        self.showDetails = showDetails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        source = try container.decodeIfPresent(MacStickySource.self, forKey: .source) ?? .smart
        frame = try container.decodeIfPresent(MacStickyWindowFrame.self, forKey: .frame) ?? .initial
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? false
        isFloating = try container.decodeIfPresent(Bool.self, forKey: .isFloating) ?? true
        showDetails = try container.decodeIfPresent(Bool.self, forKey: .showDetails) ?? false
    }
}

import AppKit
import SwiftData
import SwiftUI

/// 便笺纸张固定为浅色，不随系统深色模式变化，文字始终为深色。
enum MacStickyPalette {
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    /// 原版 Stickies 的黄：正文 #FEF49C，标题条 #FEEA3D。
    static let yellowBody = Color(red: 254 / 255, green: 244 / 255, blue: 156 / 255)
    static let yellowBar = Color(red: 254 / 255, green: 234 / 255, blue: 61 / 255)

    /// 单象限便笺的纸色（正文）与标题条色，四合一的格子与智能排列的行底复用。
    static func body(for category: TaskCategory) -> Color { tint(category.themeColor, toward: 0.84) }
    static func bar(for category: TaskCategory) -> Color { tint(category.themeColor, toward: 0.64) }

    /// 向白色混合，得到分类色的浅色调。
    static func tint(_ color: Color, toward fraction: Double) -> Color {
        let base = NSColor(color).usingColorSpace(.sRGB) ?? .gray
        return Color(nsColor: base.blended(withFraction: fraction, of: .white) ?? base)
    }
}

extension MacStickySource {
    /// 便笺正文底色：象限取分类浅色调，四合一与智能排列用 Stickies 黄。
    var bodyColor: Color {
        guard let category else { return MacStickyPalette.yellowBody }
        return MacStickyPalette.body(for: category)
    }

    /// 标题条底色，规则同正文。
    var barColor: Color {
        guard let category else { return MacStickyPalette.yellowBar }
        return MacStickyPalette.bar(for: category)
    }
}

import SwiftUI

struct AppTheme {

    // MARK: - NEXT-GEN Colors
    struct Colors {
        // 使用 Display P3 色域获取更广阔的色彩表现
        static let urgentImportant = Color(red: 1.0, green: 0.2, blue: 0.3) // Neon Red
        static let importantNotUrgent = Color(red: 0.2, green: 0.5, blue: 1.0) // Electric Blue
        static let urgentNotImportant = Color(red: 0.0, green: 0.9, blue: 0.5) // Cyber Green
        static let normal = Color(red: 0.7, green: 0.7, blue: 0.8) // Holographic Grey

        // 动态流体背景
        static let backgroundGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "F0F4FF"),
                Color(hex: "E6EFFF"),
                Color(hex: "D9E2FF")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let darkBackgroundGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "0A0B1E"),
                Color(hex: "15173B"),
                Color(hex: "050505")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Day / Night Palettes
    // 两套配色方案，可直接用于 UI 层。同一色族在两套中保持视觉关系一致。

    /// 日间模式配色（温暖、清晰）
    struct DayPalette {
        // 文字
        static let textPrimary   = Color(hex: "1C2B4B") // 深海蓝
        static let textSecondary = Color(hex: "6B7897") // 石板灰

        // 背景 & 面板
        static let background    = Color(hex: "F7F9FC") // 冷调白
        static let surface        = Color(hex: "FFFFFF") // 纯白卡片
        static let separator      = Color(hex: "E2E8F0") // 浅蓝分隔线

        // 功能色
        static let accentBlue    = Color(hex: "4A7CF7") // 冷静蓝
        static let accentGreen   = Color(hex: "34C97E") // 清新绿
        static let accentAmber   = Color(hex: "F5A623") // 暖琥珀
        static let accentRed     = Color(hex: "FF5A5A") // 柔红

        // 渐变背景
        static let backgroundGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "F7F9FC"),
                Color(hex: "EDF2FF"),
                Color(hex: "E6EDFA")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 夜间模式配色（深邃、专注）
    struct NightPalette {
        // 文字
        static let textPrimary   = Color(hex: "E8EFF9") // 月光银
        static let textSecondary = Color(hex: "8A9BB5") // 暗钢蓝

        // 背景 & 面板
        static let background    = Color(hex: "0E1523") // 深夜蓝
        static let surface        = Color(hex: "1A2236") // 深蓝卡片
        static let separator      = Color(hex: "2A3548") // 深蓝分隔线

        // 功能色（同色族，亮度上调以适配深色背景）
        static let accentBlue    = Color(hex: "6B94F7") // 星空蓝
        static let accentGreen   = Color(hex: "4DD889") // 极光绿
        static let accentAmber   = Color(hex: "FFC043") // 金色琥珀
        static let accentRed     = Color(hex: "FF7070") // 柔玫红

        // 渐变背景
        static let backgroundGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "0E1523"),
                Color(hex: "15203A"),
                Color(hex: "0A1020")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Dimensions & Physics
    struct Radius {
        static let card: CGFloat = 16 // 恢复较小的圆角，增加内容显示面积
        static let button: CGFloat = 12
        static let bubble: CGFloat = 12
    }
    
    struct Padding {
        static let standard: CGFloat = 12 // 减少内边距 (20 -> 12)
        static let loose: CGFloat = 20
        static let compact: CGFloat = 8
    }
    
    struct Shadows {
        static let glow = ShadowStyle(color: .blue.opacity(0.3), radius: 20, x: 0, y: 0)
        static let float = ShadowStyle(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
    }
}

struct ShadowStyle {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
}

// MARK: - View Modifiers for The "Future" Look

extension View {
    /// 现代化玻璃卡片：利用原生 Material 和 Shape API
    func holographicCard() -> some View {
        self
            .padding(AppTheme.Padding.compact) // 使用更紧凑的内边距 (8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    
    /// 霓虹辉光效果：仅保留基础阴影，减少过度的图形计算
    func standardGlow(color: Color) -> some View {
        self.shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}


// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

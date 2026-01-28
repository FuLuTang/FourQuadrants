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
    
    // MARK: - Dimensions & Physics
    struct Radius {
        static let card: CGFloat = 28 // 更大的圆角，更有机
        static let button: CGFloat = 16
        static let bubble: CGFloat = 20
    }
    
    struct Padding {
        static let standard: CGFloat = 20
        static let loose: CGFloat = 32
        static let compact: CGFloat = 12
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
            .padding(AppTheme.Padding.standard)
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

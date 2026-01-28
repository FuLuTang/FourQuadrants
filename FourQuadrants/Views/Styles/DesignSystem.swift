import SwiftUI

/// 🎨 FourQuadrants Design System - iOS 26 Vision
/// 核心理念: Spatiality (空间感), Fluidity (流动性), Smart Materials (智能材质)
struct AppTheme {
    
    // MARK: - NEXT-GEN Colors
    struct Colors {
        // 使用 Display P3 色域获取更广阔的色彩表现
        static let urgentImportant = Color(displayP3Red: 1.0, green: 0.2, blue: 0.35, opacity: 1.0)
        static let importantNotUrgent = Color(displayP3Red: 0.2, green: 0.6, blue: 1.0, opacity: 1.0)
        static let urgentNotImportant = Color(displayP3Red: 1.0, green: 0.7, blue: 0.2, opacity: 1.0)
        static let notImportantNotUrgent = Color(displayP3Red: 0.0, green: 0.85, blue: 0.65, opacity: 1.0)
        
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        
        // MARK: - Liquid Mesh Background (Build-in MeshGradient)
        // iOS 18+ Built-in MeshGradient (Liquid Glass Foundation)
        static var backgroundGradient: some View {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(0.3, 0.5), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ],
                colors: [
                    Color(hex: "F2F6FF"), Color(hex: "EBF2FA"), Color(hex: "E5EBF5"),
                    Color(hex: "DAE4F5"), Color(hex: "EBF2FA"), Color(hex: "D0DBED"),
                    Color(hex: "F5F8FF"), Color(hex: "E0E9F5"), Color(hex: "EBF2FA")
                ]
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Dimensions & Physics
    struct Radius {
        static let card: CGFloat = 32 // Super ellipitcal feel
        static let button: CGFloat = 20
        static let bubble: CGFloat = 24
    }
    
    struct Padding {
        static let standard: CGFloat = 24
        static let loose: CGFloat = 36
        static let compact: CGFloat = 16
    }
    
    struct Shadows {
        static let glow = ShadowStyle(color: .blue.opacity(0.3), radius: 24, x: 0, y: 0)
        static let float = ShadowStyle(color: .black.opacity(0.12), radius: 20, x: 0, y: 12)
        static let innerHighlight = ShadowStyle(color: .white.opacity(0.5), radius: 1, x: -1, y: -1)
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
    /// 全息玻璃卡片：极细腻的磨砂 + 动态高光边缘
    func holographicCard(opacity: Double = 0.6) -> some View {
        self
            .padding(AppTheme.Padding.standard)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            // The "Liquid Glass" edge light is handled by native material interaction with light, 
            // but we add a subtle border for contrast on light mode
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 10)
    }
    
    /// 霓虹辉光效果：用于强调按钮或重要状态
    func neonGlow(color: Color) -> some View {
        self.shadow(color: color.opacity(0.6), radius: 15, x: 0, y: 0)
             .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 0)
    }
    
    /// 悬浮交互反馈
    func floatOnTap() -> some View {
        self.buttonStyle(FloatButtonStyle())
    }
}

// MARK: - Custom Interactions

struct FloatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: configuration.isPressed)
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

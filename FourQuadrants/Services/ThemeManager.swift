import SwiftUI
import Combine

/// 主题管理器 - 负责应用内亮/暗色模式切换
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// 支持的主题模式
    enum AppThemeMode: String, CaseIterable, Identifiable {
        case auto = "auto"    // 跟随系统
        case light = "light"  // 日间模式
        case dark = "dark"    // 夜间模式

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .auto:
                return String(localized: "theme_auto", locale: LanguageManager.shared.locale)
            case .light:
                return String(localized: "theme_light", locale: LanguageManager.shared.locale)
            case .dark:
                return String(localized: "theme_dark", locale: LanguageManager.shared.locale)
            }
        }

        var icon: String {
            switch self {
            case .auto:  return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark:  return "moon.fill"
            }
        }
    }

    /// 固定顺序的主题选项（自动 → 日间 → 夜间）
    static let orderedModes: [AppThemeMode] = [.auto, .light, .dark]

    /// 当前选择的主题
    @Published var currentTheme: AppThemeMode {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "selectedTheme") ?? "auto"
        self.currentTheme = AppThemeMode(rawValue: saved) ?? .auto
    }

    /// 映射到 SwiftUI ColorScheme（nil 表示跟随系统）
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .auto:  return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }

    /// 循环切换到下一个主题（自动 → 日间 → 夜间 → 自动）
    func cycleTheme() {
        let modes = ThemeManager.orderedModes
        guard let idx = modes.firstIndex(of: currentTheme) else { return }
        currentTheme = modes[(idx + 1) % modes.count]
    }
}

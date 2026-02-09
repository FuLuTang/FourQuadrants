import SwiftUI
import Foundation

/// 语言管理器 - 负责应用内语言切换
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    /// 支持的语言
    enum Language: String, CaseIterable, Identifiable {
        case auto = "auto"        // 跟随系统
        case english = "en"       // 英语
        case chinese = "zh-Hans"  // 简体中文
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .auto:
                return String(localized: "language_auto")
            case .english:
                return "English"
            case .chinese:
                return "简体中文"
            }
        }
        
        var flag: String {
            switch self {
            case .auto:
                return "🌐"
            case .english:
                return "🇺🇸"
            case .chinese:
                return "🇨🇳"
            }
        }
    }
    
    /// 当前选择的语言
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
            updateLocale()
        }
    }
    
    /// 实际使用的 Locale
    @Published var locale: Locale
    
    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "auto"
        let language = Language(rawValue: savedLanguage) ?? .auto
        self.currentLanguage = language
        self.locale = LanguageManager.getLocale(for: language)
    }
    
    /// 获取系统语言
    static var systemLanguage: String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("zh-Hans") || preferredLanguage.hasPrefix("zh-CN") {
            return "zh-Hans"
        } else if preferredLanguage.hasPrefix("zh-Hant") || preferredLanguage.hasPrefix("zh-TW") {
            return "zh-Hant"
        } else {
            return String(preferredLanguage.prefix(2))
        }
    }
    
    /// 获取系统语言的显示名称
    static var systemLanguageDisplayName: String {
        let code = systemLanguage
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }
    
    private static func getLocale(for language: Language) -> Locale {
        switch language {
        case .auto:
            let systemLang = systemLanguage
            if systemLang.hasPrefix("zh") {
                return Locale(identifier: "zh-Hans")
            } else {
                return Locale(identifier: "en")
            }
        case .english:
            return Locale(identifier: "en")
        case .chinese:
            return Locale(identifier: "zh-Hans")
        }
    }
    
    private func updateLocale() {
        locale = LanguageManager.getLocale(for: currentLanguage)
    }
    
    var effectiveLanguageCode: String {
        if currentLanguage == .auto {
            return LanguageManager.systemLanguage
        }
        return currentLanguage.rawValue
    }
}

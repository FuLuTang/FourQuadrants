import SwiftUI
import Combine
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
                return String(localized: "language_auto", locale: LanguageManager.shared.locale)
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
            updateAppleLanguages()
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
        updateAppleLanguages()
    }
    
    /// 强制更新底层 AppleLanguages (使得 String(localized:) 和系统弹窗如通知也能立刻匹配应用内语言设置)
    private func updateAppleLanguages() {
        if currentLanguage == .auto {
            // "自动" 意味着跟随 iOS 系统的语言设置 (包含系统级多语言和iOS设置中的独立App语言)
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            // 用户在应用内做出了具体的选择，无视 iOS 的设定，覆盖 AppleLanguages
            // 对于繁简中文我们需要区分，但这里目前只有 zh-Hans
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
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

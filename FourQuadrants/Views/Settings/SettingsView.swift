import SwiftUI

enum ThemeMode: Int, CaseIterable {
    case auto = 0
    case light = 1
    case dark = 2
    
    var colorSchemePreference: ColorScheme? {
        switch self {
        case .auto:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var iconName: String {
        switch self {
        case .auto:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon.fill"
        }
    }
    
    var titleKey: String {
        switch self {
        case .auto:
            return "settings_theme_auto"
        case .light:
            return "settings_theme_light"
        case .dark:
            return "settings_theme_dark"
        }
    }
    
    func next() -> ThemeMode {
        switch self {
        case .auto:
            return .light
        case .light:
            return .dark
        case .dark:
            return .auto
        }
    }
}

struct SettingsView: View {
    // 用户偏好设置
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("themeMode") private var themeModeRaw = -1
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("darkModeFollowSystem") private var darkModeFollowSystem = true
    
    // 用于打开系统设置
    @Environment(\.openURL) private var openURL
    
    // 用于控制 colorScheme
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.modelContext) private var modelContext
    
    // 定义导航路径类型
    private enum Route: Hashable {
        case about
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 应用设置区块
                Section(header: Text("settings_app_section")) {
                    // 通知开关
                    Toggle("settings_enable_notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            handleNotificationToggle(enabled: newValue)
                        }
                    
                    // 主题模式：自动 / 亮色 / 深色（三态按钮）
                    Button {
                        themeMode = themeMode.next()
                    } label: {
                        HStack {
                            Image(systemName: themeMode.iconName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("settings_theme_mode")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(LocalizedStringKey(themeMode.titleKey))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 语言设置
                Section(header: Text("settings_language_section")) {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Text("settings_language")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "")
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Sync Settings
                Section(header: Text("settings_sync_section")) {
                    SyncSettingsView()
                }
                
                // 修改后的关于区块
                Section(header: Text("settings_about_section")) {
                    NavigationLink("settings_details", value: Route.about)
                }
            }
            .navigationTitle("settings_title")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .about:
                    AboutDetailView()
                        .toolbar(.hidden, for: .tabBar) // 隐藏底部TabBar
                }
            }
        }
        .preferredColorScheme(colorSchemePreference)
        .onAppear {
            migrateLegacyThemeSettingIfNeeded()
        }
    }
    
    // 计算当前应该使用的 colorScheme
    private var colorSchemePreference: ColorScheme? {
        themeMode.colorSchemePreference
    }
    
    private var themeMode: ThemeMode {
        get {
            ThemeMode(rawValue: themeModeRaw) ?? .auto
        }
        nonmutating set {
            themeModeRaw = newValue.rawValue
        }
    }
    
    private func migrateLegacyThemeSettingIfNeeded() {
        guard themeModeRaw == -1 else { return }
        
        if darkModeFollowSystem {
            themeMode = .auto
        } else {
            themeMode = darkModeEnabled ? .dark : .light
        }
    }
    
    // 处理通知开关变化
    private func handleNotificationToggle(enabled: Bool) {
        if enabled {
            // 请求通知权限
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if !granted {
                    // 如果用户拒绝，需要引导用户去设置
                    DispatchQueue.main.async {
                        notificationsEnabled = false
                    }
                    print("⚠️ 通知权限被拒绝")
                }
            }
        } else {
            // 立即结束灵动岛
            LiveActivityManager.shared.checkTask(context: modelContext)
            print("ℹ️ 用户已关闭通知，灵动岛已停止")
        }
    }
}

// 新增关于详情视图
struct AboutDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    
    // 从 Bundle 读取版本信息
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        List {
            // App 标识区
            Section {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        // App 图标
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .overlay(
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("app_name_cn")
                                .font(.title2.bold())
                            Text("app_name_en")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("about_version \(appVersion) (\(buildNumber))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                    }
                    
                    // 彩蛋：App 理念
                    HStack(spacing: 0) {
                        Text("slogan_char1")
                            .foregroundStyle(.blue)
                            .fontWeight(.bold)
                        Text("slogan_part1")
                        Text("slogan_char2")
                            .foregroundStyle(.purple)
                            .fontWeight(.bold)
                        Text("slogan_part2")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.vertical, 8)
            }
            
            // 功能亮点
            Section(header: Text("about_features_title")) {
                FeatureRow(icon: "square.grid.2x2", title: String(localized: "feature_quadrant_board"), description: String(localized: "feature_quadrant_desc"))
                FeatureRow(icon: "hand.draw", title: String(localized: "feature_drag_drop"), description: String(localized: "feature_drag_desc"))
                FeatureRow(icon: "clock.badge.exclamationmark", title: String(localized: "feature_smart_urgent"), description: String(localized: "feature_urgent_desc"))
                FeatureRow(icon: "arrow.triangle.2.circlepath", title: String(localized: "feature_microsoft_sync"), description: String(localized: "feature_sync_desc"))
            }
            
            // 开发者
            Section(header: Text("about_developer_title")) {
                LabeledContent("about_design_dev", value: "FuLuTang")
                LabeledContent("about_tech_stack", value: "SwiftUI + SwiftData")
                LabeledContent("about_min_support", value: "iOS 17.0")
            }
            
            // 反馈与支持
            Section(header: Text("about_feedback_title")) {
                Button {
                    if let url = URL(string: "mailto:tanghaochen0506@hotmail.com?subject=TotalFeedback") {
                        openURL(url)
                    }
                } label: {
                    Label("feedback_send_email", systemImage: "envelope")
                }
                
                Button {
                    if let url = URL(string: "https://github.com/fulutang/FourQuadrants") {
                        openURL(url)
                    }
                } label: {
                    Label("feedback_github", systemImage: "link")
                }
                
                Button {
                    // 跳转到 App Store 评分页面
                    if let url = URL(string: "https://apps.apple.com/app/idYOURAPPID?action=write-review") {
                        openURL(url)
                    }
                } label: {
                    Label("feedback_rate", systemImage: "star")
                }
            }
            
            // 法律信息
            Section(header: Text("about_legal")) {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Text("legal_privacy")
                }
                
                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    Text("legal_terms")
                }
            }
            
            // 版权
            Section {
                Text("copyright_notice")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("settings_about_section")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 功能行组件
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// 隐私政策占位视图
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("privacy_title")
                    .font(.title.bold())
                
                Text("privacy_intro")
                    .font(.body)
                
                Text("privacy_data_storage_title")
                    .font(.headline)
                Text("privacy_data_storage_desc")
                
                Text("privacy_data_collection_title")
                    .font(.headline)
                Text("privacy_data_collection_desc")
                
                Text("privacy_third_party_title")
                    .font(.headline)
                Text("privacy_third_party_desc")
            }
            .padding()
        }
        .navigationTitle("privacy_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 服务条款占位视图
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("terms_title")
                    .font(.title.bold())
                
                Text("terms_intro")
                    .font(.body)
                
                Text("terms_license_title")
                    .font(.headline)
                Text("terms_license_desc")
                
                Text("terms_disclaimer_title")
                    .font(.headline)
                Text("terms_disclaimer_desc")
            }
            .padding()
        }
        .navigationTitle("terms_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
struct SyncSettingsView: View {
    @ObservedObject var syncService = SyncService.shared
    
    var body: some View {
        if syncService.isAuthenticated {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("sync_connected")
                        .font(.headline)
                }
                
                if let lastSync = syncService.lastSyncTime {
                    Text("sync_last_time \(lastSync.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                     Text("sync_never")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if syncService.isSyncing {
                    ProgressView()
                }
                
                Button(role: .destructive) {
                    syncService.signOut()
                } label: {
                    Text("sync_disconnect")
                }
            }
            .padding(.vertical, 4)
        } else {
            Button {
                Task {
                    await syncService.signIn()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("sync_connect_microsoft")
                }
            }
        }
        
        if let error = syncService.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

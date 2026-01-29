import SwiftUI

struct SettingsView: View {
    // 定义导航路径类型
    private enum Route: Hashable {
        case about
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 保留原有应用设置区块
                Section(header: Text("应用设置")) {
                    Toggle("启用通知", isOn: .constant(true))
                    Toggle("暗黑模式", isOn: .constant(false))
                }
                
                // Sync Settings
                Section(header: Text("同步")) {
                    SyncSettingsView()
                }
                
                // 修改后的关于区块
                Section(header: Text("关于")) {
                    NavigationLink("详细信息", value: Route.about)
                }
            }
            .navigationTitle("设置")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .about:
                    AboutDetailView()
                        .toolbar(.hidden, for: .tabBar) // 隐藏底部TabBar
                }
            }
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
                            Text("项限")
                                .font(.title2.bold())
                            Text("Quadrant")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("版本 \(appVersion) (\(buildNumber))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                    }
                    
                    // 彩蛋：App 理念
                    HStack(spacing: 0) {
                        Text("项")
                            .foregroundStyle(.blue)
                            .fontWeight(.bold)
                        Text("目有重，")
                        Text("限")
                            .foregroundStyle(.purple)
                            .fontWeight(.bold)
                        Text("时先行。")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.vertical, 8)
            }
            
            // 功能亮点
            Section(header: Text("功能亮点")) {
                FeatureRow(icon: "square.grid.2x2", title: "四象限看板", description: "基于艾森豪威尔矩阵的任务管理")
                FeatureRow(icon: "hand.draw", title: "拖拽分类", description: "长按任务即可拖拽到其他象限")
                FeatureRow(icon: "clock.badge.exclamationmark", title: "智能紧急", description: "根据截止日期自动判断紧急程度")
                FeatureRow(icon: "arrow.triangle.2.circlepath", title: "微软同步", description: "与 Microsoft To Do 双向同步")
            }
            
            // 开发者
            Section(header: Text("开发者")) {
                LabeledContent("设计 & 开发", value: "唐颢宸")
                LabeledContent("技术栈", value: "SwiftUI + SwiftData")
                LabeledContent("最低支持", value: "iOS 17.0")
            }
            
            // 反馈与支持
            Section(header: Text("反馈与支持")) {
                Button {
                    if let url = URL(string: "mailto:your.email@example.com?subject=四象限反馈") {
                        openURL(url)
                    }
                } label: {
                    Label("发送反馈邮件", systemImage: "envelope")
                }
                
                Button {
                    if let url = URL(string: "https://github.com/yourusername/FourQuadrants") {
                        openURL(url)
                    }
                } label: {
                    Label("GitHub 仓库", systemImage: "link")
                }
                
                Button {
                    // 跳转到 App Store 评分页面
                    if let url = URL(string: "https://apps.apple.com/app/idYOURAPPID?action=write-review") {
                        openURL(url)
                    }
                } label: {
                    Label("为我们评分", systemImage: "star")
                }
            }
            
            // 法律信息
            Section(header: Text("法律信息")) {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Text("隐私政策")
                }
                
                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    Text("服务条款")
                }
            }
            
            // 版权
            Section {
                Text("© 2026 FourQuadrants. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("关于")
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
                Text("隐私政策")
                    .font(.title.bold())
                
                Text("本应用尊重并保护您的隐私。")
                    .font(.body)
                
                Text("数据存储")
                    .font(.headline)
                Text("所有任务数据仅存储在您的设备本地。如果您选择启用 Microsoft To Do 同步，数据将通过微软官方 API 传输并存储在您的微软账户中。")
                
                Text("数据收集")
                    .font(.headline)
                Text("我们不收集任何个人信息或使用数据。")
                
                Text("第三方服务")
                    .font(.headline)
                Text("本应用使用 Microsoft Graph API 进行任务同步。使用该功能时，您的数据将受微软隐私政策保护。")
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 服务条款占位视图
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("服务条款")
                    .font(.title.bold())
                
                Text("欢迎使用四象限应用。")
                    .font(.body)
                
                Text("使用许可")
                    .font(.headline)
                Text("本应用授予您有限的、非独占的、不可转让的许可，仅供个人非商业用途。")
                
                Text("免责声明")
                    .font(.headline)
                Text("本应用按原样提供，不做任何明示或暗示的保证。")
            }
            .padding()
        }
        .navigationTitle("服务条款")
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
                    Text("已连接 Microsoft To Do")
                        .font(.headline)
                }
                
                if let lastSync = syncService.lastSyncTime {
                    Text("上次同步: \(lastSync.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                     Text("尚未同步")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if syncService.isSyncing {
                    ProgressView()
                }
                
                Button(role: .destructive) {
                    syncService.signOut()
                } label: {
                    Text("断开连接")
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
                    Text("连接 Microsoft To Do")
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

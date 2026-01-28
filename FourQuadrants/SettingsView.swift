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
                .listRowBackground(Material.ultraThin)
                
                // Sync Settings
                Section(header: Text("同步")) {
                    SyncSettingsView()
                }
                .listRowBackground(Material.ultraThin)
                
                // 修改后的关于区块
                Section(header: Text("关于")) {
                    NavigationLink("详细信息", value: Route.about)
                }
                .listRowBackground(Material.ultraThin)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear) // Let AppContainer gradient show
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
    @Environment(\.dismiss) var dismiss // 用于返回操作
    
    var body: some View {
        Form {
            Section(header: Text("本应用")) {
                Text("版本: 1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            Section(header: Text("开发者")) {
                Text("设计: 你自己")
                Text("开发: 你自己")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("返回") {
                    dismiss()
                }
            }
        }
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
                Swift.Task { @MainActor in
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

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
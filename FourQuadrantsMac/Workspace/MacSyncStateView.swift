import SwiftUI

struct MacSyncStateView: View {
    let state: MacSyncStatus

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.callout.weight(.medium))
                if let detail {
                    detail.font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }

    private var title: Text {
        switch state {
        case .inactive: Text("未连接")
        case .connecting: Text("正在连接 Microsoft…")
        case .syncing: Text("正在同步任务…")
        case let .connected(_, syncEnabled): syncEnabled ? Text("同步已就绪") : Text("账户已连接")
        case .failed: Text("同步遇到问题")
        }
    }

    private var detail: Text? {
        switch state {
        case .inactive: Text("连接账户后可在设备间同步任务。")
        case .connecting: Text("请在 Microsoft 登录窗口中完成授权。")
        case .syncing: Text("本地任务会继续保存在此设备。")
        case let .connected(lastSync, syncEnabled):
            if let lastSync { Text("最近同步：\(lastSync.formatted(date: .abbreviated, time: .shortened))") }
            else { syncEnabled ? Text("等待首次同步。") : Text("自动同步已关闭。") }
        case let .failed(message): Text(verbatim: message)
        }
    }

    private var symbol: String {
        switch state {
        case .inactive: "icloud.slash"
        case .connecting, .syncing: "arrow.triangle.2.circlepath"
        case .connected: "checkmark.icloud.fill"
        case .failed: "exclamationmark.icloud.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .inactive: .secondary
        case .connecting, .syncing: .blue
        case .connected: .green
        case .failed: .orange
        }
    }
}

enum MacSyncStatus: Equatable {
    case inactive
    case connecting
    case syncing
    case connected(lastSync: Date?, syncEnabled: Bool)
    case failed(message: String)
}

#Preview("同步状态") {
    Form {
        MacSyncStateView(state: .inactive)
        MacSyncStateView(state: .connecting)
        MacSyncStateView(state: .syncing)
        MacSyncStateView(state: .connected(lastSync: .now, syncEnabled: true))
        MacSyncStateView(state: .failed(message: "网络暂时不可用。"))
    }
    .formStyle(.grouped)
    .padding()
}

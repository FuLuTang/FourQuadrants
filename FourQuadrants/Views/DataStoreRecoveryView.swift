import SwiftUI

struct DataStoreRecoveryView: View {
    let error: PersistenceError
    let retry: () -> Void
    let reset: () -> Void
    @State private var showsResetConfirmation = false

    var body: some View {
        ContentUnavailableView {
            Label("无法打开本地数据", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)
            Button("重置本地数据", role: .destructive) {
                showsResetConfirmation = true
            }
            .buttonStyle(.bordered)
        }
        .confirmationDialog("重置会永久删除此设备上的所有任务，且无法恢复。", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
            Button("重置本地数据", role: .destructive, action: reset)
            Button("取消", role: .cancel) {}
        }
    }
}

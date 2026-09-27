import SwiftUI

public struct MacRecoveryView: View {
    let error: PersistenceError
    let retry: () -> Void
    let reset: () -> Void
    @State private var isConfirmingReset = false

    init(error: PersistenceError, retry: @escaping () -> Void, reset: @escaping () -> Void) {
        self.error = error
        self.retry = retry
        self.reset = reset
    }

    public var body: some View {
        ContentUnavailableView {
            Label("无法打开本地数据", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            VStack(spacing: 8) {
                Text(error.localizedDescription)
                Text("重置会删除此设备上的本地数据。只有在重试仍失败时才建议重置。")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        } actions: {
            HStack(spacing: 10) {
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
                Button("重置本地数据", role: .destructive) {
                    isConfirmingReset = true
                }
                .buttonStyle(.bordered)
            }
        }
        .confirmationDialog("重置本地数据？", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("永久删除本地数据", role: .destructive, action: reset)
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销。确认前请确保你已了解本地数据影响。")
        }
        .frame(minWidth: 560, minHeight: 360)
    }
}

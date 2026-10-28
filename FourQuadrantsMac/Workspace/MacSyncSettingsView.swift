import SwiftUI

struct MacSyncSettingsView: View {
    @ObservedObject private var syncService = SyncService.shared
    @State private var showsInitialMerge = false
    @State private var showsDisconnectConfirmation = false
    @State private var showsDiagnostic = false
    @State private var healthReport: MacLocalSyncHealthReport?
    @State private var isRunningHealthCheck = false

    private var previewDataMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--preview-data")
    }

    private var status: MacSyncStatus {
        if syncService.isSigningIn { return .connecting }
        if syncService.isSyncing { return .syncing }
        if let error = syncService.errorMessage { return .failed(message: error) }
        if syncService.isAuthenticated {
            return .connected(lastSync: syncService.lastSyncTime, syncEnabled: syncService.isSyncEnabled)
        }
        return .inactive
    }

    var body: some View {
        Form {
            Section("Microsoft To Do") {
                MacSyncStateView(state: status)
                if syncService.isAuthenticated {
                    LabeledContent("最近同步", value: syncService.lastSyncTime?.formatted(date: .abbreviated, time: .shortened) ?? "尚未同步")
                    Toggle("自动同步", isOn: Binding(get: { syncService.isSyncEnabled }, set: { syncService.setSyncEnabled($0) }))
                        .disabled(previewDataMode)
                    HStack {
                        Button {
                            Task { await syncService.synchronize() }
                        } label: {
                            Label(syncService.isSyncing ? "正在同步" : "立即同步", systemImage: "arrow.clockwise")
                        }
                        .disabled(previewDataMode || syncService.isSyncing || !syncService.isSyncEnabled)

                        if syncService.isSyncing { ProgressView().controlSize(.small) }
                        Spacer()
                        Button("退出账户", role: .destructive) { showsDisconnectConfirmation = true }
                            .disabled(previewDataMode)
                    }
                } else {
                    Button {
                        Task {
                            await syncService.signIn()
                            showsInitialMerge = syncService.needsInitialMerge
                        }
                    } label: {
                        Label(syncService.isSigningIn ? "正在连接…" : "连接 Microsoft To Do", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .disabled(previewDataMode || syncService.isSigningIn)
                    if syncService.isSigningIn { ProgressView("正在打开 Microsoft 登录页面…") }
                }

                if previewDataMode {
                    Label("预览数据模式：已停用登录、同步和健康检查操作。", systemImage: "eye")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let error = syncService.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section("诊断") {
                Button {
                    runLocalHealthCheck()
                } label: {
                    Label(isRunningHealthCheck ? "正在检查…" : "运行本机同步健康检查", systemImage: "stethoscope")
                }
                .disabled(previewDataMode || isRunningHealthCheck || syncService.isSyncing || !syncService.isAuthenticated || !syncService.isSyncEnabled)

                Button("查看最近检查", systemImage: "doc.text.magnifyingglass") {
                    showsDiagnostic = true
                }
                .disabled(healthReport == nil)
                Text("检查会运行一次普通同步，并依据本机记录的最近成功时间和错误提示汇总；不会创建测试任务。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("首次合并") {
                Text("首次同步时，你可以选择要上传到 Microsoft To Do 的本地任务。")
                    .foregroundStyle(.secondary)
                if syncService.needsInitialMerge {
                    Button("选择并开始合并", systemImage: "arrow.triangle.merge") { showsInitialMerge = true }
                        .disabled(previewDataMode)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("同步")
        .frame(maxWidth: 760, alignment: .leading)
        .padding(20)
        .sheet(isPresented: $showsInitialMerge) {
            MacInitialMergeView(syncService: syncService)
                .frame(minWidth: 540, minHeight: 420)
        }
        .sheet(isPresented: $showsDiagnostic) {
            MacSyncDiagnosticView(report: healthReport)
                .frame(minWidth: 600, minHeight: 420)
        }
        .confirmationDialog("退出 Microsoft To Do？", isPresented: $showsDisconnectConfirmation, titleVisibility: .visible) {
            Button("退出账户", role: .destructive) { syncService.signOut() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("本地任务会保留。")
        }
        .onAppear { showsInitialMerge = syncService.needsInitialMerge && !previewDataMode }
        .onChange(of: syncService.needsInitialMerge) { _, needed in
            if needed && !previewDataMode { showsInitialMerge = true }
        }
    }

    private func runLocalHealthCheck() {
        guard !previewDataMode, !isRunningHealthCheck else { return }
        isRunningHealthCheck = true
        let startedAt = Date()
        Task { @MainActor in
            await syncService.synchronize()
            let lastSync = syncService.lastSyncTime
            let error = syncService.errorMessage
            let succeeded = error == nil && (lastSync.map { $0 >= startedAt } ?? false)
            healthReport = MacLocalSyncHealthReport(
                checkedAt: Date(),
                succeeded: succeeded,
                lastSuccessfulSync: lastSync,
                message: error ?? (succeeded ? nil : "本次调用未记录新的成功同步时间。")
            )
            isRunningHealthCheck = false
        }
    }
}

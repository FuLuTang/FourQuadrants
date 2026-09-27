import AppKit
import SwiftUI
import UserNotifications

struct MacSettingsView: View {
    @AppStorage("themeMode") private var themeMode = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Environment(\.openURL) private var openURL
    @State private var notificationNotice: String?

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink {
                    MacAppearanceSettingsView(themeMode: $themeMode)
                } label: {
                    Label("外观与通知", systemImage: "paintbrush")
                }
                NavigationLink {
                    MacSyncSettingsView()
                } label: {
                    Label("同步", systemImage: "arrow.triangle.2.circlepath")
                }
                NavigationLink {
                    MacAboutView(openURL: openURL)
                } label: {
                    Label("关于", systemImage: "info.circle")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } detail: {
            MacAppearanceSettingsView(themeMode: $themeMode)
        }
        .frame(minWidth: 720, minHeight: 480)
        .alert("通知设置", isPresented: Binding(get: { notificationNotice != nil }, set: { if !$0 { notificationNotice = nil } })) {
            Button("好", role: .cancel) { notificationNotice = nil }
        } message: {
            Text(notificationNotice ?? "")
        }
        .onChange(of: notificationsEnabled) { _, enabled in
            guard enabled else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                Task { @MainActor in
                    if let error {
                        notificationsEnabled = false
                        notificationNotice = error.localizedDescription
                    } else if !granted {
                        notificationsEnabled = false
                        notificationNotice = "系统未授予通知权限。你可以在系统设置的通知页面中更改此选项。"
                    }
                }
            }
        }
    }
}

private struct MacAppearanceSettingsView: View {
    @Binding var themeMode: Int

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: $themeMode) {
                    Text("自动").tag(0)
                    Text("浅色").tag(1)
                    Text("深色").tag(2)
                }
                .pickerStyle(.segmented)
                Text("主题偏好由主窗口统一应用。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("通知") {
                Toggle("允许任务通知", isOn: notificationBinding)
                Text("开启时，系统会请求通知权限。你可以随时在 macOS 系统设置中调整权限。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("外观与通知")
        .frame(maxWidth: 720, alignment: .leading)
        .padding(20)
    }

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { notificationsEnabled },
            set: { enabled in
                notificationsEnabled = enabled
            }
        )
    }
}

private struct MacAboutView: View {
    let openURL: OpenURLAction

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("四象限").font(.title2.weight(.semibold))
                        Text("Four Quadrants").foregroundStyle(.secondary)
                        Text("版本 \(version)").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("产品") {
                LabeledContent("技术", value: "SwiftUI · SwiftData")
                Text("用清晰的四象限视图梳理任务、日期与日程。")
                    .foregroundStyle(.secondary)
            }

            Section("帮助与反馈") {
                Button {
                    if let url = URL(string: "https://github.com/fulutang/FourQuadrants") { openURL(url) }
                } label: {
                    Label("项目主页", systemImage: "link")
                }
                Button {
                    if let url = URL(string: "mailto:tanghaochen0506@hotmail.com?subject=FourQuadrants%20Feedback") { openURL(url) }
                } label: {
                    Label("发送反馈", systemImage: "envelope")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("关于")
        .frame(maxWidth: 720, alignment: .leading)
        .padding(20)
    }
}

private struct MacSyncSettingsView: View {
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

private struct MacInitialMergeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var syncService: SyncService
    @State private var selectedIDs: Set<UUID>

    init(syncService: SyncService) {
        self.syncService = syncService
        _selectedIDs = State(initialValue: Set(syncService.pendingInitialTasks.map(\.id)))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("首次合并").font(.title2.weight(.semibold))
                    Text("选择要上传到 Microsoft To Do 的本地任务。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("稍后") {
                    dismiss()
                }
                Button("开始同步") {
                    Task {
                        await syncService.completeInitialMerge(includedLocalTaskIDs: selectedIDs)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(18)
            Divider()
            List(syncService.pendingInitialTasks) { task in
                Toggle(isOn: selection(for: task.id)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                        Text(task.isCompleted ? "已完成" : "将上传到 Microsoft To Do")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func selection(for id: UUID) -> Binding<Bool> {
        Binding(get: { selectedIDs.contains(id) }, set: { value in
            if value { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
        })
    }
}

private struct MacSyncDiagnosticView: View {
    let report: MacLocalSyncHealthReport?
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    private var copyText: String {
        guard let report else { return "" }
        return [
            "Mac 本机同步健康检查",
            "检查时间：\(report.checkedAt.formatted(date: .long, time: .shortened))",
            "结果：\(report.succeeded ? "成功" : "未确认成功")",
            "最近成功同步：\(report.lastSuccessfulSync?.formatted(date: .long, time: .shortened) ?? "无")",
            "错误：\(report.message ?? "无")"
        ].joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本机同步健康检查").font(.title2.weight(.semibold))
                    if let report {
                        Text(report.checkedAt.formatted(date: .long, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(didCopy ? "已复制" : "复制报告", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(copyText, forType: .string)
                    didCopy = true
                }
                Button("关闭", action: { dismiss() })
            }
            if let report {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    GridRow { Text("结果").foregroundStyle(.secondary); Text(report.succeeded ? "成功" : "未确认成功") }
                    GridRow { Text("最近成功同步").foregroundStyle(.secondary); Text(report.lastSuccessfulSync?.formatted(date: .long, time: .shortened) ?? "无") }
                }
                if let error = report.message {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
                Text(copyText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            } else {
                ContentUnavailableView("暂无健康检查", systemImage: "stethoscope", description: Text("运行一次本机同步健康检查后，结果会显示在这里。"))
            }
        }
        .padding(20)
    }
}

private struct MacSyncStateView: View {
    let state: MacSyncStatus

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }

    private var title: String {
        switch state {
        case .inactive: "未连接"
        case .connecting: "正在连接 Microsoft…"
        case .syncing: "正在同步任务…"
        case let .connected(_, syncEnabled): syncEnabled ? "同步已就绪" : "账户已连接"
        case .failed: "同步遇到问题"
        }
    }

    private var detail: String? {
        switch state {
        case .inactive: "连接账户后可在设备间同步任务。"
        case .connecting: "请在 Microsoft 登录窗口中完成授权。"
        case .syncing: "本地任务会继续保存在此设备。"
        case let .connected(lastSync, syncEnabled):
            if let lastSync { "最近同步：\(lastSync.formatted(date: .abbreviated, time: .shortened))" }
            else { syncEnabled ? "等待首次同步。" : "自动同步已关闭。" }
        case let .failed(message): message
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

private enum MacSyncStatus: Equatable {
    case inactive
    case connecting
    case syncing
    case connected(lastSync: Date?, syncEnabled: Bool)
    case failed(message: String)
}

private struct MacLocalSyncHealthReport {
    let checkedAt: Date
    let succeeded: Bool
    let lastSuccessfulSync: Date?
    let message: String?
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

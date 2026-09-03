#if DEBUG
import SwiftUI
import UIKit

struct MicrosoftTodoSyncDiagnosticsView: View {
    @ObservedObject private var syncService = SyncService.shared
    @State private var showsConfirmation = false

    var body: some View {
        Form {
            Section {
                Button {
                    showsConfirmation = true
                } label: {
                    Label("运行一次远端往返诊断", systemImage: "stethoscope")
                }
                .disabled(syncService.isRunningDiagnostic || syncService.isSyncing || !syncService.isSyncEnabled)
            } footer: {
                Text("会创建 8 条随机四象限字段的 Microsoft To Do 测试任务，读回并导入校验后自动删除。")
            }

            Section("测试进度") {
                ForEach(Array(syncService.diagnosticSteps.enumerated()), id: \.element.id) { index, check in
                    diagnosticStepRow(
                        check,
                        showsConnector: index < syncService.diagnosticSteps.count - 1
                    )
                }
            }

            if let result = syncService.diagnosticResult {
                Section("结果") {
                    switch result {
                    case .running:
                        Text(syncService.diagnosticHasFailure ? "检查失败，正在清理测试任务" : "正在运行完整测试套件")
                    case .success:
                        Label("全部检查点通过，测试任务已清理", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case let .failure(message, remoteTaskIdentifiers):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        if !remoteTaskIdentifiers.isEmpty {
                            LabeledContent("待清理任务", value: remoteTaskIdentifiers.joined(separator: ", "))
                                .font(.caption)
                        }
                    }

                    if !syncService.diagnosticLog.isEmpty {
                        Button {
                            UIPasteboard.general.string = syncService.diagnosticLog
                        } label: {
                            Label("复制诊断日志", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
        }
        .navigationTitle("同步诊断")
        .confirmationDialog("运行同步诊断？", isPresented: $showsConfirmation, titleVisibility: .visible) {
            Button("开始诊断") {
                Task { await syncService.runRoundTripDiagnostic() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("8 条随机测试任务会短暂出现在默认 Tasks 清单中，完成校验后自动删除。")
        }
    }

    @ViewBuilder
    private func diagnosticStepRow(
        _ check: SyncDiagnosticStepResult,
        showsConnector: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                diagnosticStatusIndicator(for: check.status)
                    .frame(width: 24, height: 24)

                if showsConnector {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(check.step.title)
                switch check.status {
                case .failed(let message):
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                default:
                    Text(check.step.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minHeight: 52, alignment: .top)
    }

    @ViewBuilder
    private func diagnosticStatusIndicator(for status: SyncDiagnosticStepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
#endif

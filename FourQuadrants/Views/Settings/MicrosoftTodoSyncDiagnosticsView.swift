import SwiftUI
import UIKit

/// Observes a normal sync. It never creates diagnostic tasks or retains task data.
struct MicrosoftTodoSyncDiagnosticsView: View {
    @ObservedObject private var syncService = SyncService.shared

    var body: some View {
        Form {
            Section {
                Button {
                    Task { await syncService.runSyncDiagnostic() }
                } label: {
                    Label(String(localized: "sync_diagnostic_run"), systemImage: "stethoscope")
                }
                .disabled(syncService.isSyncing || !syncService.isSyncEnabled)
                .accessibilityLabel("运行 Microsoft To Do 同步诊断")
            } footer: {
                Text(String(localized: "sync_diagnostic_privacy"))
            }

            if let report = syncService.syncDiagnosticReport {
                Section(String(localized: "sync_diagnostic_latest_report")) {
                    LabeledContent("开始", value: report.startedAt.formatted(date: .abbreviated, time: .shortened))
                    if let finishedAt = report.finishedAt { LabeledContent("完成", value: finishedAt.formatted(date: .abbreviated, time: .shortened)) }
                    LabeledContent("结果", value: report.succeeded == true ? "成功" : "失败")
                    LabeledContent("Delta 条目", value: "\(report.pulledEntries)")
                    LabeledContent("导入 / 更新 / 删除", value: "\(report.imported) / \(report.updated) / \(report.deleted)")
                    LabeledContent("保留本地 Outbox", value: "\(report.pendingLocalPreserved)")
                    if !report.patchFields.isEmpty { LabeledContent("PATCH 字段", value: summary(report.patchFields)) }
                    if !report.observations.isEmpty { LabeledContent("字段观测", value: observationSummary(report.observations)) }
                    if let error = report.errorSummary { LabeledContent("错误", value: error) }
                    Button {
                        UIPasteboard.general.string = syncService.copyableSyncDiagnosticText()
                    } label: { Label(String(localized: "sync_diagnostic_copy"), systemImage: "doc.on.doc") }
                    .accessibilityLabel("复制无敏感信息同步诊断报告")
                }
            }

            Section("建议验证") {
                Text("在 Microsoft To Do 编辑高重要性、描述和到期日；再在四象限中拖入“重要不紧急”。运行诊断后查看 PATCH 字段是否含 importance，以及字段观测是否显示 value、null 或 unobserved。")
                Text("若要确认远端最终字段，请在开发工具中明确触发一次单任务读取；常规同步不会为诊断额外循环请求。")
            }
        }
        .navigationTitle("同步诊断")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ values: [String: Int]) -> String {
        values.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: "，")
    }

    private func observationSummary(_ values: [String: [String: Int]]) -> String {
        values.sorted { $0.key < $1.key }.map { key, states in
            "\(key): " + states.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: "，")
        }.joined(separator: "\n")
    }
}

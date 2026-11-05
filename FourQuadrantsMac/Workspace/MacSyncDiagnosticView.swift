import AppKit
import SwiftUI

struct MacLocalSyncHealthReport {
    let checkedAt: Date
    let succeeded: Bool
    let lastSuccessfulSync: Date?
    let message: String?
}

struct MacSyncDiagnosticView: View {
    let report: MacLocalSyncHealthReport?
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    private var copyText: String {
        guard let report else { return "" }
        return [
            String(localized: "Mac 本机同步健康检查"),
            String(localized: "检查时间：\(report.checkedAt.formatted(date: .long, time: .shortened))"),
            String(localized: "结果：\(report.succeeded ? String(localized: "成功") : String(localized: "未确认成功"))"),
            String(localized: "最近成功同步：\(report.lastSuccessfulSync?.formatted(date: .long, time: .shortened) ?? String(localized: "无"))"),
            String(localized: "错误：\(report.message ?? String(localized: "无"))")
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
                    GridRow { Text("最近成功同步").foregroundStyle(.secondary); Text(report.lastSuccessfulSync?.formatted(date: .long, time: .shortened) ?? String(localized: "无")) }
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

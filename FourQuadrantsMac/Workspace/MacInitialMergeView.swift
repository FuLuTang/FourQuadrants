import SwiftUI

struct MacInitialMergeView: View {
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

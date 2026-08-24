import SwiftUI

struct MicrosoftTodoInitialMergeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var syncService: SyncService
    @State private var selectedTaskIDs: Set<UUID>

    init(syncService: SyncService) {
        self.syncService = syncService
        _selectedTaskIDs = State(initialValue: Set(syncService.pendingInitialTasks.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(syncService.pendingInitialTasks) { task in
                    Toggle(isOn: selection(for: task.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                            Text(task.isCompleted ? "已完成" : "将同步到 Microsoft To Do")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("首次同步")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后") {
                        syncService.cancelInitialMerge()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始同步") {
                        let identifiers = selectedTaskIDs
                        Task {
                            await syncService.completeInitialMerge(includedLocalTaskIDs: identifiers)
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func selection(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedTaskIDs.contains(id) },
            set: { isSelected in
                if isSelected {
                    selectedTaskIDs.insert(id)
                } else {
                    selectedTaskIDs.remove(id)
                }
            }
        )
    }
}

import SwiftUI

/// The settings destination for the Microsoft bridge.
///
/// Keeping bridge controls here leaves the root settings screen focused on
/// app-wide preferences, while the board status button remains a lightweight
/// entry point for observation.
struct SyncCenterSettingsView: View {
    @ObservedObject private var syncService = SyncService.shared

    var body: some View {
        Form {
            Section {
                SyncSettingsView()
            } header: {
                Text("Microsoft To Do")
            } footer: {
                Text("同步会将标题、备注、日期、完成状态、重要性和四象限信息发送至 Microsoft To Do。")
            }

            Section("同步诊断") {
                NavigationLink {
                    MicrosoftTodoSyncDiagnosticsView()
                } label: {
                    Label("Microsoft To Do 同步诊断", systemImage: "stethoscope")
                }
                .disabled(syncService.isSyncing)
            }
        }
        .navigationTitle("同步")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SyncCenterSettingsView()
    }
}

import SwiftUI

/// A compact, app-wide status affordance for the Microsoft To Do bridge.
///
/// The control intentionally represents the synchronizer as one status surface
/// rather than exposing the state of individual tasks in the board.
struct SyncStatusControl: View {
    @ObservedObject private var syncService: SyncService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingDetails = false

    init(syncService: SyncService = .shared) {
        _syncService = ObservedObject(wrappedValue: syncService)
    }

    var body: some View {
        Button {
            isShowingDetails = true
        } label: {
            statusIcon
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(statusTitle))
        .accessibilityValue(Text(statusSummary))
        .accessibilityHint(Text("sync_status_details_hint"))
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $isShowingDetails) {
            SyncStatusDetailsView(syncService: syncService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch syncService.syncPresentationState {
        case .connecting, .syncing:
            ProgressView()
                .controlSize(.small)
                .tint(.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                )
                .accessibilityHidden(true)
        case .succeeded:
            Image(systemName: "checkmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.green))
                .accessibilityHidden(true)
        case .failed:
            Image(systemName: "xmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.red))
                .accessibilityHidden(true)
        case .inactive:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(.secondarySystemBackground)))
                .accessibilityHidden(true)
        }
    }

    private var statusTitle: String {
        switch syncService.syncPresentationState {
        case .connecting: return String(localized: "sync_status_connecting")
        case .syncing: return String(localized: "sync_status_syncing")
        case .succeeded: return String(localized: "sync_status_succeeded")
        case .failed: return String(localized: "sync_status_failed")
        case .inactive: return String(localized: "sync_status_inactive")
        }
    }

    private var statusSummary: String {
        switch syncService.syncPresentationState {
        case .connecting: return String(localized: "sync_status_connecting_detail")
        case .syncing: return String(localized: "sync_status_syncing_detail")
        case let .succeeded(lastSync):
            guard let lastSync else { return String(localized: "sync_status_never_synced") }
            return lastSync.formatted(date: .abbreviated, time: .shortened)
        case let .failed(message): return message
        case .inactive: return String(localized: "sync_status_inactive_detail")
        }
    }
}

struct SyncStatusDetailsView: View {
    @ObservedObject var syncService: SyncService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        statusIcon
                            .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusTitle)
                                .font(.headline)
                            Text(statusDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(statusTitle))
                    .accessibilityValue(Text(statusDescription))
                }

                Section(String(localized: "sync_status_details_section")) {
                    if let accountName = syncService.accountName,
                       syncService.isAuthenticated {
                        LabeledContent(String(localized: "sync_status_account"), value: accountName)
                    }

                    LabeledContent(String(localized: "sync_status_last_sync"), value: lastSyncText)

                    LabeledContent(
                        String(localized: "sync_status_automatic_sync"),
                        value: syncService.isSyncEnabled
                            ? String(localized: "sync_status_enabled")
                            : String(localized: "sync_status_disabled")
                    )
                }

                if case let .failed(message) = syncService.syncPresentationState {
                    Section(String(localized: "sync_status_error_section")) {
                        Label {
                            Text(message)
                                .textSelection(.enabled)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle(Text("sync_status_details_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch syncService.syncPresentationState {
        case .connecting, .syncing:
            ProgressView()
                .controlSize(.small)
                .tint(.accentColor)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        case .succeeded:
            Image(systemName: "checkmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.green))
        case .failed:
            Image(systemName: "xmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.red))
        case .inactive:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        }
    }

    private var statusTitle: String {
        switch syncService.syncPresentationState {
        case .connecting: return String(localized: "sync_status_connecting")
        case .syncing: return String(localized: "sync_status_syncing")
        case .succeeded: return String(localized: "sync_status_succeeded")
        case .failed: return String(localized: "sync_status_failed")
        case .inactive: return String(localized: "sync_status_inactive")
        }
    }

    private var statusDescription: String {
        switch syncService.syncPresentationState {
        case .connecting: return String(localized: "sync_status_connecting_detail")
        case .syncing: return String(localized: "sync_status_syncing_detail")
        case let .succeeded(lastSync):
            guard let lastSync else { return String(localized: "sync_status_never_synced") }
            return String(format: String(localized: "sync_status_last_sync_format"), lastSync.formatted(date: .abbreviated, time: .shortened))
        case let .failed(message): return message
        case .inactive: return String(localized: "sync_status_inactive_detail")
        }
    }

    private var lastSyncText: String {
        guard let lastSync = syncService.lastSyncTime else {
            return String(localized: "sync_status_never_synced")
        }
        return lastSync.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview("Sync status") {
    SyncStatusControl()
        .padding()
}

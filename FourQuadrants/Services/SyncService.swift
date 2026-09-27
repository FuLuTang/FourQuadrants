import Combine
import Foundation
import MSAL
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()
    private static let taskDeltaQueryVersion = 2
    private static let automaticSyncDelay: Duration = .seconds(1)
    private static let diagnosticProbeCount = 8

    @Published private(set) var isSyncing = false
    @Published private(set) var isSigningIn = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var isAuthenticated = false
    @Published var errorMessage: String?
    @Published private(set) var accountName: String?
    @Published private(set) var pendingInitialTasks: [QuadrantTask] = []
    @Published private(set) var isPresentingInitialMerge = false
    @Published private(set) var diagnosticResult: SyncDiagnosticResult?
    @Published private(set) var diagnosticSteps = SyncDiagnosticStep.allCases.map {
        SyncDiagnosticStepResult(step: $0, status: .pending)
    }
    @Published private(set) var diagnosticLog = ""
    @Published private(set) var isRunningDiagnostic = false

    var needsInitialMerge: Bool { isPresentingInitialMerge && !pendingInitialTasks.isEmpty }
    var hasDeferredInitialMerge: Bool {
        activeProfile.map { !$0.hasCompletedInitialMerge } ?? false
    }
    var isSyncEnabled: Bool { activeProfile?.isEnabled ?? false }
    var diagnosticHasFailure: Bool {
        diagnosticSteps.contains {
            if case .failed = $0.status { return true }
            return false
        }
    }

    private var modelContext: ModelContext?
    private weak var taskStore: TaskStore?
    private let graph = MicrosoftGraphClient()
    private var application: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?
    private var signInAttemptID: UUID?
    private var scheduledSyncTask: Task<Void, Never>?
    private var retrySyncTask: Task<Void, Never>?
    private var requiresAnotherSync = false

    private init() {}

    func configure(modelContext: ModelContext, taskStore: TaskStore) {
        self.modelContext = modelContext
        self.taskStore = taskStore
        taskStore.quadrantTaskMutationRecorder = { [weak self] mutation in
            try self?.recordDurableMutation(mutation)
        }
        taskStore.quadrantTaskMutationDidCommit = { [weak self] in
            self?.scheduleAutomaticSync()
        }
        restoreCachedAccount()
        do {
            try repairStoredDueDateKeys()
            try modelContext.save()
        } catch {
            errorMessage = userFacingError(error)
        }
        repairSyncRecordsForActiveProfile()
        restorePendingInitialMerge()
        schedulePendingRetryIfNeeded()
        refreshPublishedState()
    }

    func signIn() async {
        guard !isSigningIn else { return }
        let attemptID = UUID()
        signInAttemptID = attemptID
        isSigningIn = true
        errorMessage = nil

        do {
            let result = try await acquireInteractiveToken()
            guard signInAttemptID == attemptID else { return }
            currentAccount = result.account
            isAuthenticated = true
            accountName = result.account.username
            errorMessage = nil
            try await prepareProfile(account: result.account, accessToken: result.accessToken)
            try prepareInitialMergeIfNeeded(present: true)
        } catch {
            guard signInAttemptID == attemptID else { return }
            errorMessage = userFacingError(error)
        }

        guard signInAttemptID == attemptID else { return }
        signInAttemptID = nil
        isSigningIn = false
    }

    func cancelSignIn() {
        guard isSigningIn else { return }
        signInAttemptID = nil
        isSigningIn = false
        _ = MSALPublicClientApplication.cancelCurrentWebAuthSession()
        errorMessage = "连接已取消。请确认网络能打开 Microsoft 登录页后重试。"
    }

    func completeInitialMerge(includedLocalTaskIDs: Set<UUID>) async {
        guard let profile = activeProfile else { return }
        do {
            for task in pendingInitialTasks {
                let state: MicrosoftTodoLinkState = includedLocalTaskIDs.contains(task.id) ? .pendingUpload : .localOnly
                let link = MicrosoftTodoTaskLink(profileIdentifier: profile.id, localTaskIdentifier: task.id, state: state)
                modelContext?.insert(link)
                if state != .localOnly {
                    enqueueOperation(
                        kind: .create,
                        profile: profile,
                        localTaskID: task.id,
                        remoteTaskID: nil,
                        expectedETag: nil,
                        localUpdatedAt: task.updatedAt
                    )
                }
            }
            profile.hasCompletedInitialMerge = true
            profile.updatedAt = Date()
            try modelContext?.save()
            pendingInitialTasks = []
            isPresentingInitialMerge = false
            await synchronize()
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    func cancelInitialMerge() {
        isPresentingInitialMerge = false
    }

    func resumeInitialMerge() {
        do {
            try prepareInitialMergeIfNeeded(present: true)
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    func setSyncEnabled(_ enabled: Bool) {
        guard let profile = activeProfile else { return }
        profile.isEnabled = enabled
        profile.updatedAt = Date()
        saveContext()
        if enabled { Task { await synchronize() } }
    }

    func synchronize() async {
        guard !isRunningDiagnostic else { return }
        guard let profile = activeProfile, profile.isEnabled else { return }
        guard !isSyncing else {
            requiresAnotherSync = true
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        var didRetryAfterDeltaReset = false
        repeat {
            requiresAnotherSync = false
            let shouldRetryAfterDeltaReset = await synchronize(profile: profile)
            if shouldRetryAfterDeltaReset, didRetryAfterDeltaReset {
                errorMessage = "Microsoft To Do 同步游标重置后仍然失败，请稍后重试。"
                break
            }
            didRetryAfterDeltaReset = didRetryAfterDeltaReset || shouldRetryAfterDeltaReset
            requiresAnotherSync = requiresAnotherSync || shouldRetryAfterDeltaReset
        } while requiresAnotherSync
    }

    /// Runs an isolated, real Graph round trip using the same payload and import path as production sync.
    func runRoundTripDiagnostic() async {
        guard !isRunningDiagnostic, !isSyncing else { return }
        guard let profile = activeProfile, profile.isEnabled else {
            diagnosticResult = .failure("请先连接 Microsoft To Do 并打开同步开关。")
            return
        }

        scheduledSyncTask?.cancel()
        scheduledSyncTask = nil
        isRunningDiagnostic = true
        diagnosticResult = .running
        resetDiagnosticSteps()
        resetDiagnosticLog()
        defer { isRunningDiagnostic = false }

        let probes = (0 ..< Self.diagnosticProbeCount).map { _ in makeDiagnosticProbe() }
        var remoteTasks: [MicrosoftTodoTask] = []

        do {
            setDiagnosticStep(.createAndRestore, status: .running)
            appendDiagnosticLog("节点 1 开始：创建并从云端恢复。")
            let token = try await acquireSilentToken()
            for probe in probes {
                let created = try await graph.createTask(
                    listID: profile.defaultListIdentifier,
                    payload: payload(for: probe, profile: profile, includingMetadata: true),
                    token: token
                )
                remoteTasks.append(created)
                appendDiagnosticLog("已创建远端任务 local=\(probe.id.uuidString) remote=\(created.id)。")

                let fetchedTask = try await graph.fetchTask(
                    listID: profile.defaultListIdentifier,
                    taskID: created.id,
                    token: token
                )
                let fetchedMetadata = try await graph.fetchTaskMetadata(
                    listID: profile.defaultListIdentifier,
                    taskID: created.id,
                    token: token
                )
                remoteTasks[remoteTasks.count - 1] = fetchedTask.replacingExtensions([fetchedMetadata])
            }

            try apply(remoteTasks, profile: profile)
            try modelContext?.save()

            for probe in probes {
                guard let restored = try localTask(id: probe.id) else {
                    throw SyncError.diagnosticImportMissing(probe.title)
                }
                let mismatches = diagnosticMismatches(expected: .init(task: probe), actual: restored)
                guard mismatches.isEmpty else {
                    appendDiagnosticLog("节点 1 字段不一致 local=\(probe.id.uuidString) fields=\(mismatches.joined(separator: ", ")) expected={\(diagnosticFieldSummary(for: SyncDiagnosticTaskSnapshot(task: probe)))} actual={\(diagnosticFieldSummary(for: restored))}")
                    throw SyncError.diagnosticMismatch(probe.title, mismatches)
                }
            }

            setDiagnosticStep(.createAndRestore, status: .passed)
            appendDiagnosticLog("节点 1 通过：8 条任务字段一致。")
            setDiagnosticStep(.moveAndResync, status: .running)
            appendDiagnosticLog("节点 2 开始：移动象限后再次同步。")

            guard let taskStore else { throw SyncError.notConfigured }
            guard let editedTask = try localTask(id: probes[0].id) else {
                throw SyncError.diagnosticImportMissing(probes[0].title)
            }
            let destination = diagnosticDestination(for: editedTask)
            appendDiagnosticLog("移动 local=\(editedTask.id.uuidString) destination=\(destination.rawValue)。")
            guard taskStore.moveTask(editedTask, to: destination) else {
                throw SyncError.diagnosticMoveFailed(editedTask.title)
            }
            guard editedTask.category == destination else {
                throw SyncError.diagnosticMoveFailed(editedTask.title)
            }
            let expectedEditedTask = SyncDiagnosticTaskSnapshot(task: editedTask)
            appendDiagnosticLog("移动后期望字段={\(diagnosticFieldSummary(for: expectedEditedTask))}")

            try await synchronizeForDiagnostic(profile: profile)
            guard let remoteTaskID = try remoteTaskIdentifier(for: editedTask.id, profileID: profile.id) else {
                throw SyncError.diagnosticImportMissing(editedTask.title)
            }
            appendDiagnosticLog("生产同步完成 local=\(editedTask.id.uuidString) remote=\(remoteTaskID) \(try diagnosticLinkSummary(localTaskID: editedTask.id, profileID: profile.id))")
            let updatedRemoteTask = try await graph.fetchTask(
                listID: profile.defaultListIdentifier,
                taskID: remoteTaskID,
                token: token
            )
            let updatedMetadata = try await graph.fetchTaskMetadata(
                listID: profile.defaultListIdentifier,
                taskID: remoteTaskID,
                token: token
            )
            let restoredRemoteTask = updatedRemoteTask.replacingExtensions([updatedMetadata])
            try apply([restoredRemoteTask], profile: profile)
            try modelContext?.save()
            remoteTasks[0] = restoredRemoteTask

            guard let restoredEditedTask = try localTask(id: editedTask.id) else {
                throw SyncError.diagnosticImportMissing(editedTask.title)
            }
            let editedMismatches = diagnosticMismatches(expected: expectedEditedTask, actual: restoredEditedTask)
            guard editedMismatches.isEmpty else {
                appendDiagnosticLog("节点 2 字段不一致 local=\(editedTask.id.uuidString) remote=\(remoteTaskID) fields=\(editedMismatches.joined(separator: ", ")) expected={\(diagnosticFieldSummary(for: expectedEditedTask))} actual={\(diagnosticFieldSummary(for: restoredEditedTask))}")
                throw SyncError.diagnosticMismatch(editedTask.title, editedMismatches)
            }
            setDiagnosticStep(.moveAndResync, status: .passed)
            appendDiagnosticLog("节点 2 通过：移动后的字段一致。")

            try await cleanUpDiagnostic(probes: probes, remoteTasks: remoteTasks, profile: profile, token: token)
            appendDiagnosticLog("清理完成：8 条远端测试任务与本地导入记录已删除。")
            diagnosticResult = .success
        } catch {
            let diagnosticError = userFacingError(error)
            appendDiagnosticLog("诊断失败：\(diagnosticError)")
            failActiveDiagnosticStep(with: diagnosticError)
            guard !remoteTasks.isEmpty else {
                diagnosticResult = .failure(diagnosticError)
                return
            }

            do {
                try await cleanUpDiagnostic(
                    probes: probes,
                    remoteTasks: remoteTasks,
                    profile: profile,
                    token: try await acquireSilentToken()
                )
                appendDiagnosticLog("失败后的清理完成。")
                diagnosticResult = .failure(diagnosticError)
            } catch {
                appendDiagnosticLog("清理失败：\(userFacingError(error))")
                diagnosticResult = .failure(
                    "\(diagnosticError) 测试任务清理失败：\(userFacingError(error))",
                    remoteTaskIdentifiers: remoteTasks.map(\.id)
                )
            }
        }
    }

    private func synchronizeForDiagnostic(profile: MicrosoftTodoSyncProfile) async throws {
        do {
            try await performSynchronization(profile: profile)
        } catch let error as MicrosoftGraphError where requiresDeltaReset(error) {
            profile.deltaLink = nil
            try modelContext?.save()
            try await performSynchronization(profile: profile)
        }
    }

    private func synchronize(profile: MicrosoftTodoSyncProfile) async -> Bool {
        do {
            try await performSynchronization(profile: profile)
            return false
        } catch is CancellationError {
            return false
        } catch let error as MicrosoftGraphError {
            if requiresDeltaReset(error) {
                profile.deltaLink = nil
                saveContext()
                return true
            } else {
                errorMessage = userFacingError(error)
                return false
            }
        } catch {
            errorMessage = userFacingError(error)
            return false
        }
    }

    private func performSynchronization(profile: MicrosoftTodoSyncProfile) async throws {
        errorMessage = nil
        try repairSyncRecords(profile: profile)
        try repairStoredDueDateKeys()
        try modelContext?.save()
        let token = try await acquireSilentToken()
        try await pullRemoteChanges(profile: profile, token: token)
        try await pushLocalChanges(profile: profile, token: token)
        profile.lastSuccessfulSyncAt = Date()
        profile.updatedAt = Date()
        try modelContext?.save()
        lastSyncTime = profile.lastSuccessfulSyncAt
    }

    func signOut() {
        guard let application, let currentAccount else {
            isAuthenticated = false
            accountName = nil
            return
        }
        do {
            try application.remove(currentAccount)
        } catch {
            errorMessage = userFacingError(error)
            return
        }
        self.currentAccount = nil
        self.isAuthenticated = false
        self.accountName = nil
    }

    private var activeProfile: MicrosoftTodoSyncProfile? {
        guard let context = modelContext, let accountID = currentAccount?.identifier else { return nil }
        let descriptor = FetchDescriptor<MicrosoftTodoSyncProfile>(predicate: #Predicate { $0.accountIdentifier == accountID })
        return try? context.fetch(descriptor).first
    }

    private func prepareProfile(account: MSALAccount, accessToken: String) async throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        if activeProfile != nil { return }
        let defaultList = try await findDefaultList(token: accessToken)
        let listID = defaultList.id
        guard let accountIdentifier = account.identifier else { throw SyncError.authenticationFailed }
        context.insert(MicrosoftTodoSyncProfile(
            accountIdentifier: accountIdentifier,
            displayName: account.username ?? "Microsoft account",
            defaultListIdentifier: listID
        ))
        try context.save()
        refreshPublishedState()
    }

    private func findDefaultList(token: String) async throws -> MicrosoftTodoList {
        var nextURL: URL?
        repeat {
            let page = try await graph.listDeltaPage(url: nextURL, token: token)
            if let list = page.value.first(where: { $0.wellknownListName == "defaultList" }) { return list }
            nextURL = page.nextLink.flatMap(URL.init(string:))
        } while nextURL != nil
        throw SyncError.defaultListNotFound
    }

    private func pullRemoteChanges(profile: MicrosoftTodoSyncProfile, token: String) async throws {
        let needsDeltaQueryUpgrade = UserDefaults.standard.integer(forKey: deltaQueryVersionKey(for: profile)) < Self.taskDeltaQueryVersion
        var nextURL = needsDeltaQueryUpgrade ? nil : profile.deltaLink.flatMap(URL.init(string:))
        let isFullScan = nextURL == nil
        var seenRemoteTaskIDs: Set<String> = []
        var finalDeltaLink: String?
        repeat {
            let page = try await graph.taskDeltaPage(listID: profile.defaultListIdentifier, url: nextURL, token: token)
            seenRemoteTaskIDs.formUnion(page.value.filter { $0.removed == nil }.map(\.id))
            try apply(page.value, profile: profile)
            try modelContext?.save()
            nextURL = page.nextLink.flatMap(URL.init(string:))
            finalDeltaLink = page.deltaLink ?? finalDeltaLink
        } while nextURL != nil
        if isFullScan {
            try reconcileMissingRemoteTasks(profile: profile, seenRemoteTaskIDs: seenRemoteTaskIDs)
        }
        if let finalDeltaLink {
            profile.deltaLink = finalDeltaLink
            UserDefaults.standard.set(Self.taskDeltaQueryVersion, forKey: deltaQueryVersionKey(for: profile))
        }
    }

    private func reconcileMissingRemoteTasks(
        profile: MicrosoftTodoSyncProfile,
        seenRemoteTaskIDs: Set<String>
    ) throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let profileID = profile.id
        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate {
            $0.profileIdentifier == profileID
        }))
        for link in links {
            guard let remoteID = link.remoteTaskIdentifier, !seenRemoteTaskIDs.contains(remoteID) else { continue }
            switch link.state {
            case .pendingUpload, .remoteCreated, .unknownCreateResult:
                link.remoteTaskIdentifier = nil
                link.remoteETag = nil
                link.remoteLastModifiedAt = nil
                enqueueOperation(
                    kind: .create,
                    profile: profile,
                    localTaskID: link.localTaskIdentifier,
                    remoteTaskID: nil,
                    expectedETag: nil,
                    localUpdatedAt: try localTask(id: link.localTaskIdentifier)?.updatedAt
                )
            case .pendingLocalDeletion:
                removeOperations(profileID: profileID, localTaskID: link.localTaskIdentifier)
                removeTombstones(profileID: profileID, localTaskID: link.localTaskIdentifier)
                context.delete(link)
            case .linked, .remotelyDeleted:
                if let task = try localTask(id: link.localTaskIdentifier) { context.delete(task) }
                removeOperations(profileID: profileID, localTaskID: link.localTaskIdentifier)
                context.delete(link)
            case .localOnly:
                break
            }
        }
    }

    private func apply(_ remoteTasks: [MicrosoftTodoTask], profile: MicrosoftTodoSyncProfile) throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let profileIdentifier = profile.id
        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier }))
        let linksByRemoteID = Dictionary(uniqueKeysWithValues: links.compactMap { link in
            link.remoteTaskIdentifier.map { ($0, link) }
        })
        let linksByLocalID = Dictionary(uniqueKeysWithValues: links.map { ($0.localTaskIdentifier, $0) })
        let localTasks = try context.fetch(FetchDescriptor<QuadrantTask>())
        let localByID = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })
        let tombstones = try context.fetch(FetchDescriptor<MicrosoftTodoDeletionTombstone>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier }))
        let deletedRemoteIDs = Set(tombstones.map(\.remoteTaskIdentifier))

        for remote in remoteTasks {
            let metadataLocalID = remote.fourQuadrantsMetadata?.localTaskIdentifier.flatMap(UUID.init(uuidString:))
            let link = linksByRemoteID[remote.id] ?? metadataLocalID.flatMap { linksByLocalID[$0] }
            if remote.removed != nil {
                guard let link else { continue }
                if let task = localByID[link.localTaskIdentifier] { context.delete(task) }
                removeOperations(profileID: profile.id, localTaskID: link.localTaskIdentifier)
                removeTombstones(profileID: profile.id, localTaskID: link.localTaskIdentifier)
                context.delete(link)
                continue
            }

            // A local delete is durable intent. A stale delta entry must not restore that task.
            guard !deletedRemoteIDs.contains(remote.id) else { continue }

            let remoteModifiedAt = parseDate(remote.lastModifiedDateTime) ?? Date()
            if let link, let local = localByID[link.localTaskIdentifier] {
                link.remoteTaskIdentifier = remote.id
                if link.state == .pendingLocalDeletion { continue }
                if Self.shouldKeepPendingLocalChange(
                    linkState: link.state,
                    localUpdatedAt: local.updatedAt,
                    remoteModifiedAt: remoteModifiedAt,
                    lastSyncedRemoteModifiedAt: link.remoteLastModifiedAt,
                    lastSyncedRemoteETag: link.remoteETag,
                    remoteETag: remote.eTag
                ) {
                    continue
                }
                update(local, from: remote)
                link.remoteETag = remote.eTag
                link.remoteLastModifiedAt = remoteModifiedAt
                link.lastSyncedLocalUpdatedAt = local.updatedAt
                link.state = .linked
                link.updatedAt = Date()
            } else {
                let task: QuadrantTask
                if let metadataLocalID, let local = localByID[metadataLocalID] {
                    task = local
                    update(task, from: remote)
                } else {
                    task = makeLocalTask(from: remote)
                    context.insert(task)
                }
                let newLink = MicrosoftTodoTaskLink(
                    profileIdentifier: profile.id,
                    localTaskIdentifier: task.id,
                    remoteTaskIdentifier: remote.id,
                    state: .linked
                )
                newLink.remoteETag = remote.eTag
                newLink.remoteLastModifiedAt = remoteModifiedAt
                newLink.lastSyncedLocalUpdatedAt = task.updatedAt
                context.insert(newLink)
            }
        }
    }

    private func pushLocalChanges(profile: MicrosoftTodoSyncProfile, token: String) async throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let profileIdentifier = profile.id
        let operations = try context.fetch(FetchDescriptor<MicrosoftTodoSyncOperation>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier }))
            .filter { $0.state != .permanentFailure }
            .filter { $0.nextAttemptAt.map { $0 <= Date() } ?? true }
            .sorted { $0.createdAt < $1.createdAt }

        for operation in operations {
            do {
                try await deliver(operation, profile: profile, token: token)
                try context.save()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                recordFailure(for: operation, error: error)
                try context.save()
            }
        }
        schedulePendingRetryIfNeeded()
        let remainingOperations = try context.fetch(FetchDescriptor<MicrosoftTodoSyncOperation>(predicate: #Predicate {
            $0.profileIdentifier == profileIdentifier
        }))
        if !remainingOperations.isEmpty {
            throw SyncError.pendingOperationsFailed(remainingOperations.count)
        }
    }

    private func recordDurableMutation(_ mutation: TaskStore.QuadrantTaskMutation) throws {
        guard let profile = activeProfile, let context = modelContext else { return }

        switch mutation {
        case let .upsert(taskID):
            let link = try canonicalLink(profileID: profile.id, localTaskID: taskID, in: context)
            guard profile.hasCompletedInitialMerge || link != nil else { return }
            guard link?.state != .localOnly else { return }
            let task = try localTask(id: taskID)
            let localUpdatedAt = task?.updatedAt ?? Date()

            let durableLink: MicrosoftTodoTaskLink
            if let link {
                durableLink = link
                durableLink.state = durableLink.remoteTaskIdentifier == nil ? .pendingUpload : .pendingUpload
                durableLink.updatedAt = Date()
            } else {
                durableLink = MicrosoftTodoTaskLink(profileIdentifier: profile.id, localTaskIdentifier: taskID)
                context.insert(durableLink)
            }

            enqueueOperation(
                kind: durableLink.remoteTaskIdentifier == nil ? .create : .update,
                profile: profile,
                localTaskID: taskID,
                remoteTaskID: durableLink.remoteTaskIdentifier,
                expectedETag: durableLink.remoteETag,
                localUpdatedAt: localUpdatedAt
            )

        case let .delete(taskID):
            guard let link = try canonicalLink(profileID: profile.id, localTaskID: taskID, in: context) else { return }

            if let remoteTaskID = link.remoteTaskIdentifier {
                link.state = .pendingLocalDeletion
                link.updatedAt = Date()
                upsertTombstone(
                    profile: profile,
                    localTaskID: taskID,
                    remoteTaskID: remoteTaskID,
                    remoteETag: link.remoteETag
                )
                enqueueOperation(
                    kind: .delete,
                    profile: profile,
                    localTaskID: taskID,
                    remoteTaskID: remoteTaskID,
                    expectedETag: link.remoteETag,
                    localUpdatedAt: nil
                )
            } else {
                removeOperations(profileID: profile.id, localTaskID: taskID)
                context.delete(link)
            }
        }
    }

    private func scheduleAutomaticSync() {
        retrySyncTask?.cancel()
        retrySyncTask = nil
        guard scheduledSyncTask == nil else { return }
        scheduledSyncTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.automaticSyncDelay)
            } catch is CancellationError {
                return
            } catch {
                return
            }
            self?.scheduledSyncTask = nil
            await self?.synchronize()
        }
    }

    private func deliver(
        _ operation: MicrosoftTodoSyncOperation,
        profile: MicrosoftTodoSyncProfile,
        token: String
    ) async throws {
        switch operation.operationKind {
        case .create:
            try await deliverCreate(operation, profile: profile, token: token)
        case .update:
            try await deliverUpdate(operation, profile: profile, token: token)
        case .delete:
            try await deliverDelete(operation, profile: profile, token: token)
        }
    }

    private func deliverCreate(
        _ operation: MicrosoftTodoSyncOperation,
        profile: MicrosoftTodoSyncProfile,
        token: String
    ) async throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        guard let link = try canonicalLink(profileID: profile.id, localTaskID: operation.localTaskIdentifier, in: context) else {
            context.delete(operation)
            return
        }
        guard let task = try localTask(id: operation.localTaskIdentifier) else {
            context.delete(operation)
            context.delete(link)
            return
        }

        if let remoteID = link.remoteTaskIdentifier {
            operation.operationKind = .update
            operation.remoteTaskIdentifier = remoteID
            operation.state = .queued
            try await deliverUpdate(operation, profile: profile, token: token)
            return
        }

        if operation.state == .uncertain || operation.state == .inFlight {
            if let recovered = try await findRemoteTask(
                localTaskID: task.id,
                operationID: operation.operationIdentifier,
                listID: profile.defaultListIdentifier,
                token: token
            ) {
                link.remoteTaskIdentifier = recovered.id
                link.remoteETag = recovered.eTag
                link.remoteLastModifiedAt = parseDate(recovered.lastModifiedDateTime)
                link.state = .remoteCreated
                link.updatedAt = Date()
                operation.remoteTaskIdentifier = recovered.id
                operation.operationKind = .update
                operation.state = .queued
                operation.updatedAt = Date()
                try context.save()
                try await deliverUpdate(operation, profile: profile, token: token)
                return
            }
            operation.state = .queued
        }

        operation.state = .inFlight
        operation.updatedAt = Date()
        try context.save()

        let created = try await graph.createTask(
            listID: profile.defaultListIdentifier,
            payload: payload(for: task, profile: profile, operationIdentifier: operation.operationIdentifier, includingMetadata: true),
            token: token
        )

        // This checkpoint turns a successful remote POST into durable local knowledge before another request.
        link.remoteTaskIdentifier = created.id
        link.remoteETag = created.eTag
        link.remoteLastModifiedAt = parseDate(created.lastModifiedDateTime)
        link.state = .remoteCreated
        link.updatedAt = Date()
        operation.remoteTaskIdentifier = created.id
        operation.operationKind = .update
        operation.state = .queued
        operation.updatedAt = Date()
        try context.save()

        try await deliverUpdate(operation, profile: profile, token: token)
    }

    private func deliverUpdate(
        _ operation: MicrosoftTodoSyncOperation,
        profile: MicrosoftTodoSyncProfile,
        token: String
    ) async throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        guard let link = try canonicalLink(profileID: profile.id, localTaskID: operation.localTaskIdentifier, in: context) else {
            context.delete(operation)
            return
        }
        guard let task = try localTask(id: operation.localTaskIdentifier) else {
            if let remoteID = link.remoteTaskIdentifier {
                upsertTombstone(profile: profile, localTaskID: link.localTaskIdentifier, remoteTaskID: remoteID, remoteETag: link.remoteETag)
                operation.operationKind = .delete
                operation.remoteTaskIdentifier = remoteID
                try await deliverDelete(operation, profile: profile, token: token)
            } else {
                context.delete(operation)
                context.delete(link)
            }
            return
        }
        guard let remoteID = link.remoteTaskIdentifier else {
            operation.operationKind = .create
            operation.state = .queued
            try await deliverCreate(operation, profile: profile, token: token)
            return
        }

        operation.state = .inFlight
        operation.updatedAt = Date()
        try context.save()

        let latestRemote: MicrosoftTodoTask
        do {
            latestRemote = try await graph.fetchTask(listID: profile.defaultListIdentifier, taskID: remoteID, token: token)
        } catch let error as MicrosoftGraphError where isNotFound(error) {
            deleteLocallyDeletedRemoteTask(task, link: link, in: context)
            context.delete(operation)
            removeTombstones(profileID: profile.id, localTaskID: task.id)
            return
        }

        let remote: MicrosoftTodoTask
        do {
            remote = try await graph.updateTask(
                listID: profile.defaultListIdentifier,
                taskID: remoteID,
                payload: payload(for: task, profile: profile, includingMetadata: false),
                eTag: latestRemote.eTag,
                token: token
            )
        } catch let error as MicrosoftGraphError where isPreconditionFailure(error) {
            let refreshed = try await graph.fetchTask(listID: profile.defaultListIdentifier, taskID: remoteID, token: token)
            let remoteModifiedAt = parseDate(refreshed.lastModifiedDateTime) ?? .distantPast
            guard task.updatedAt >= remoteModifiedAt else {
                update(task, from: refreshed)
                link.remoteETag = refreshed.eTag
                link.remoteLastModifiedAt = remoteModifiedAt
                link.lastSyncedLocalUpdatedAt = task.updatedAt
                link.state = .linked
                link.updatedAt = Date()
                context.delete(operation)
                return
            }
            remote = try await graph.updateTask(
                listID: profile.defaultListIdentifier,
                taskID: remoteID,
                payload: payload(for: task, profile: profile, includingMetadata: false),
                eTag: refreshed.eTag,
                token: token
            )
        } catch let error as MicrosoftGraphError where isNotFound(error) {
            deleteLocallyDeletedRemoteTask(task, link: link, in: context)
            context.delete(operation)
            removeTombstones(profileID: profile.id, localTaskID: task.id)
            return
        }

        let metadata = metadata(for: task, operationIdentifier: operation.operationIdentifier)
        do {
            try await graph.updateTaskMetadata(listID: profile.defaultListIdentifier, taskID: remoteID, metadata: metadata, token: token)
        } catch let error as MicrosoftGraphError where isNotFound(error) {
            do {
                try await graph.createTaskMetadata(listID: profile.defaultListIdentifier, taskID: remoteID, metadata: metadata, token: token)
            } catch let createError as MicrosoftGraphError where isNotFound(createError) {
                deleteLocallyDeletedRemoteTask(task, link: link, in: context)
                context.delete(operation)
                removeTombstones(profileID: profile.id, localTaskID: task.id)
                return
            }
        }

        link.remoteTaskIdentifier = remote.id
        link.remoteETag = remote.eTag
        link.remoteLastModifiedAt = parseDate(remote.lastModifiedDateTime)
        link.lastSyncedLocalUpdatedAt = task.updatedAt
        link.state = .linked
        link.updatedAt = Date()
        context.delete(operation)
    }

    private func deliverDelete(
        _ operation: MicrosoftTodoSyncOperation,
        profile: MicrosoftTodoSyncProfile,
        token: String
    ) async throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let tombstone = try tombstone(profileID: profile.id, localTaskID: operation.localTaskIdentifier, in: context)
        let remoteID = tombstone?.remoteTaskIdentifier ?? operation.remoteTaskIdentifier
        guard let remoteID else {
            context.delete(operation)
            return
        }

        do {
            try await graph.deleteTask(
                listID: profile.defaultListIdentifier,
                taskID: remoteID,
                eTag: tombstone?.remoteETag ?? operation.expectedRemoteETag,
                token: token
            )
        } catch let error as MicrosoftGraphError where isNotFound(error) {
            // A 404 already satisfies the desired delete state.
        } catch let error as MicrosoftGraphError where isPreconditionFailure(error) {
            do {
                let latest = try await graph.fetchTask(
                    listID: profile.defaultListIdentifier,
                    taskID: remoteID,
                    token: token
                )
                try await graph.deleteTask(
                    listID: profile.defaultListIdentifier,
                    taskID: remoteID,
                    eTag: latest.eTag,
                    token: token
                )
            } catch let retryError as MicrosoftGraphError where isNotFound(retryError) {
                // The task disappeared while resolving the precondition failure.
            }
        }

        if let link = try canonicalLink(profileID: profile.id, localTaskID: operation.localTaskIdentifier, in: context) {
            context.delete(link)
        }
        if let tombstone { context.delete(tombstone) }
        context.delete(operation)
    }

    private func recordFailure(for operation: MicrosoftTodoSyncOperation, error: Error) {
        operation.attemptCount += 1
        operation.lastErrorMessage = userFacingError(error)
        operation.updatedAt = Date()

        if operation.operationKind == .create, isUncertainCreateResult(error) {
            operation.state = .uncertain
            if let context = modelContext,
               let link = try? canonicalLink(profileID: operation.profileIdentifier, localTaskID: operation.localTaskIdentifier, in: context) {
                link.state = .unknownCreateResult
                link.updatedAt = Date()
            }
        } else if isRetryable(error) {
            operation.state = .retryableFailure
        } else if let graphError = error as? MicrosoftGraphError, isPreconditionFailure(graphError) {
            operation.state = .conflict
        } else {
            operation.state = .permanentFailure
        }

        if operation.state == .permanentFailure {
            operation.nextAttemptAt = nil
        } else {
            let delay = retryDelay(for: error, attempt: operation.attemptCount)
            operation.nextAttemptAt = Date().addingTimeInterval(delay)
        }
        errorMessage = operation.lastErrorMessage
    }

    private func retryDelay(for error: Error, attempt: Int) -> TimeInterval {
        if case let MicrosoftGraphError.throttled(delay) = error { return delay }
        return min(pow(2, Double(max(attempt - 1, 0))), 300)
    }

    private func isRetryable(_ error: Error) -> Bool {
        if case MicrosoftGraphError.throttled = error { return true }
        if case let MicrosoftGraphError.httpStatus(status, _) = error { return status == 429 || (500 ... 599).contains(status) }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private func isUncertainCreateResult(_ error: Error) -> Bool {
        if case let MicrosoftGraphError.httpStatus(status, _) = error { return (500 ... 599).contains(status) }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private func isPreconditionFailure(_ error: MicrosoftGraphError) -> Bool {
        if case let .httpStatus(status, _) = error { return status == 412 }
        return false
    }

    private func findRemoteTask(
        localTaskID: UUID,
        operationID: UUID,
        listID: String,
        token: String
    ) async throws -> MicrosoftTodoTask? {
        var nextURL: URL?
        repeat {
            let page = try await graph.taskDeltaPage(listID: listID, url: nextURL, token: token)
            if let match = page.value.first(where: {
                guard let metadata = $0.fourQuadrantsMetadata, $0.removed == nil else { return false }
                if metadata.operationIdentifier == operationID.uuidString { return true }
                return metadata.operationIdentifier == nil && metadata.localTaskIdentifier == localTaskID.uuidString
            }) {
                return match
            }
            nextURL = page.nextLink.flatMap(URL.init(string:))
        } while nextURL != nil
        return nil
    }

    private func canonicalLink(
        profileID: UUID,
        localTaskID: UUID,
        in context: ModelContext
    ) throws -> MicrosoftTodoTaskLink? {
        let descriptor = FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        let links = try context.fetch(descriptor)
        guard let selected = links.sorted(by: linkSortOrder).first else { return nil }
        for duplicate in links where duplicate.id != selected.id {
            moveOperations(from: duplicate, to: selected, in: context)
            context.delete(duplicate)
        }
        return selected
    }

    private func linkSortOrder(_ lhs: MicrosoftTodoTaskLink, _ rhs: MicrosoftTodoTaskLink) -> Bool {
        switch (lhs.remoteTaskIdentifier != nil, rhs.remoteTaskIdentifier != nil) {
        case (true, false): return true
        case (false, true): return false
        default: return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func moveOperations(
        from source: MicrosoftTodoTaskLink,
        to destination: MicrosoftTodoTaskLink,
        in context: ModelContext
    ) {
        let profileID = source.profileIdentifier
        let localTaskID = source.localTaskIdentifier
        let descriptor = FetchDescriptor<MicrosoftTodoSyncOperation>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        guard let operations = try? context.fetch(descriptor) else { return }
        for operation in operations {
            if operation.remoteTaskIdentifier == nil {
                operation.remoteTaskIdentifier = destination.remoteTaskIdentifier
            }
        }
    }

    private func enqueueOperation(
        kind: MicrosoftTodoOperationKind,
        profile: MicrosoftTodoSyncProfile,
        localTaskID: UUID,
        remoteTaskID: String?,
        expectedETag: String?,
        localUpdatedAt: Date?
    ) {
        guard let context = modelContext else { return }
        let profileID = profile.id
        let descriptor = FetchDescriptor<MicrosoftTodoSyncOperation>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        let existing = (try? context.fetch(descriptor)) ?? []
        let operation = existing.sorted { $0.updatedAt > $1.updatedAt }.first

        if let operation {
            operation.operationKind = operation.operationKind == .create && kind == .update ? .create : kind
            operation.remoteTaskIdentifier = remoteTaskID ?? operation.remoteTaskIdentifier
            operation.expectedRemoteETag = expectedETag ?? operation.expectedRemoteETag
            operation.localUpdatedAt = localUpdatedAt ?? operation.localUpdatedAt
            operation.state = .queued
            operation.nextAttemptAt = nil
            operation.lastErrorMessage = nil
            operation.updatedAt = Date()
            for duplicate in existing where duplicate.id != operation.id { context.delete(duplicate) }
            return
        }

        context.insert(MicrosoftTodoSyncOperation(
            profileIdentifier: profileID,
            localTaskIdentifier: localTaskID,
            remoteTaskIdentifier: remoteTaskID,
            operationKind: kind,
            expectedRemoteETag: expectedETag,
            localUpdatedAt: localUpdatedAt
        ))
    }

    private func removeOperations(profileID: UUID, localTaskID: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<MicrosoftTodoSyncOperation>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        for operation in (try? context.fetch(descriptor)) ?? [] { context.delete(operation) }
    }

    private func tombstone(
        profileID: UUID,
        localTaskID: UUID,
        in context: ModelContext
    ) throws -> MicrosoftTodoDeletionTombstone? {
        let descriptor = FetchDescriptor<MicrosoftTodoDeletionTombstone>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        let tombstones = try context.fetch(descriptor)
        guard let selected = tombstones.sorted(by: { $0.updatedAt > $1.updatedAt }).first else { return nil }
        for duplicate in tombstones where duplicate.id != selected.id { context.delete(duplicate) }
        return selected
    }

    private func upsertTombstone(
        profile: MicrosoftTodoSyncProfile,
        localTaskID: UUID,
        remoteTaskID: String,
        remoteETag: String?
    ) {
        guard let context = modelContext else { return }
        if let existing = try? tombstone(profileID: profile.id, localTaskID: localTaskID, in: context) {
            existing.remoteTaskIdentifier = remoteTaskID
            existing.remoteETag = remoteETag ?? existing.remoteETag
            existing.updatedAt = Date()
        } else {
            context.insert(MicrosoftTodoDeletionTombstone(
                profileIdentifier: profile.id,
                localTaskIdentifier: localTaskID,
                remoteTaskIdentifier: remoteTaskID,
                remoteETag: remoteETag
            ))
        }
    }

    private func removeTombstones(profileID: UUID, localTaskID: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<MicrosoftTodoDeletionTombstone>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        for tombstone in (try? context.fetch(descriptor)) ?? [] { context.delete(tombstone) }
    }

    private func repairStoredDueDateKeys() throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let tasks = try context.fetch(FetchDescriptor<QuadrantTask>())
        for task in tasks where task.dueDateKey == nil && task.dueAt != nil {
            task.restoreLegacyDueDateKeyIfNeeded()
        }
    }

    private func restorePendingInitialMerge() {
        do {
            try prepareInitialMergeIfNeeded(present: true)
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    private func prepareInitialMergeIfNeeded(present: Bool) throws {
        guard let profile = activeProfile, !profile.hasCompletedInitialMerge else {
            pendingInitialTasks = []
            isPresentingInitialMerge = false
            return
        }
        pendingInitialTasks = try localTasksWithoutLink()
        if pendingInitialTasks.isEmpty {
            profile.hasCompletedInitialMerge = true
            profile.updatedAt = Date()
            try modelContext?.save()
            isPresentingInitialMerge = false
        } else if present {
            isPresentingInitialMerge = true
        }
    }

    private func schedulePendingRetryIfNeeded() {
        retrySyncTask?.cancel()
        retrySyncTask = nil
        guard let context = modelContext, let profile = activeProfile, profile.isEnabled else { return }
        let profileID = profile.id
        let operations = (try? context.fetch(FetchDescriptor<MicrosoftTodoSyncOperation>(predicate: #Predicate {
            $0.profileIdentifier == profileID
        }))) ?? []
        guard let nextAttempt = operations
            .filter({ $0.state != .permanentFailure })
            .compactMap(\.nextAttemptAt)
            .min() else { return }
        let delay = max(nextAttempt.timeIntervalSinceNow, 0)
        retrySyncTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            self?.retrySyncTask = nil
            await self?.synchronize()
        }
    }

    private func repairSyncRecordsForActiveProfile() {
        guard let profile = activeProfile else { return }
        do {
            try repairSyncRecords(profile: profile)
            try modelContext?.save()
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    private func repairSyncRecords(profile: MicrosoftTodoSyncProfile) throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let profileID = profile.id
        let tasks = try context.fetch(FetchDescriptor<QuadrantTask>())
        let localTaskIDs = Set(tasks.map(\.id))
        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileID }))

        for localTaskID in Set(links.map(\.localTaskIdentifier)) {
            _ = try canonicalLink(profileID: profileID, localTaskID: localTaskID, in: context)
        }

        let deduplicatedLinks = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileID }))
        for remoteTaskID in Set(deduplicatedLinks.compactMap(\.remoteTaskIdentifier)) {
            let collisions = deduplicatedLinks
                .filter { $0.remoteTaskIdentifier == remoteTaskID }
                .sorted(by: linkSortOrder)
            guard let primary = collisions.first else { continue }
            for duplicate in collisions.dropFirst() {
                duplicate.remoteTaskIdentifier = nil
                duplicate.remoteETag = nil
                duplicate.remoteLastModifiedAt = nil
                duplicate.state = .pendingUpload
                duplicate.updatedAt = Date()
                enqueueOperation(
                    kind: .create,
                    profile: profile,
                    localTaskID: duplicate.localTaskIdentifier,
                    remoteTaskID: nil,
                    expectedETag: nil,
                    localUpdatedAt: nil
                )
            }
            primary.updatedAt = Date()
        }

        let repairedLinks = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileID }))
        for link in repairedLinks where !localTaskIDs.contains(link.localTaskIdentifier) {
            if let remoteID = link.remoteTaskIdentifier {
                upsertTombstone(profile: profile, localTaskID: link.localTaskIdentifier, remoteTaskID: remoteID, remoteETag: link.remoteETag)
                link.state = .pendingLocalDeletion
                enqueueOperation(kind: .delete, profile: profile, localTaskID: link.localTaskIdentifier, remoteTaskID: remoteID, expectedETag: link.remoteETag, localUpdatedAt: nil)
            } else {
                removeOperations(profileID: profileID, localTaskID: link.localTaskIdentifier)
                context.delete(link)
            }
        }

        let currentLinks = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileID }))
        let linkedTaskIDs = Set(currentLinks.map(\.localTaskIdentifier))
        for task in tasks where linkedTaskIDs.contains(task.id) {
            guard let link = try canonicalLink(profileID: profileID, localTaskID: task.id, in: context), link.state != .localOnly else { continue }
            let localTaskID = task.id
            let operations = try context.fetch(FetchDescriptor<MicrosoftTodoSyncOperation>(predicate: #Predicate {
                $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
            }))
            guard operations.isEmpty else { continue }
            if link.state == .pendingLocalDeletion, let remoteID = link.remoteTaskIdentifier {
                enqueueOperation(kind: .delete, profile: profile, localTaskID: task.id, remoteTaskID: remoteID, expectedETag: link.remoteETag, localUpdatedAt: nil)
            } else if link.state != .linked {
                enqueueOperation(kind: link.remoteTaskIdentifier == nil ? .create : .update, profile: profile, localTaskID: task.id, remoteTaskID: link.remoteTaskIdentifier, expectedETag: link.remoteETag, localUpdatedAt: task.updatedAt)
            }
        }
    }

    private func localTasksWithoutLink() throws -> [QuadrantTask] {
        guard let context = modelContext, let profile = activeProfile else { return [] }
        let profileIdentifier = profile.id
        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier }))
        let linkedIDs = Set(links.map(\.localTaskIdentifier))
        return try context.fetch(FetchDescriptor<QuadrantTask>()).filter { !linkedIDs.contains($0.id) }
    }

    private func localTask(id: UUID) throws -> QuadrantTask? {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let descriptor = FetchDescriptor<QuadrantTask>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private func remoteTaskIdentifier(for localTaskID: UUID, profileID: UUID) throws -> String? {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let descriptor = FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        return try context.fetch(descriptor).first?.remoteTaskIdentifier
    }

    static func shouldKeepPendingLocalChange(
        linkState: MicrosoftTodoLinkState,
        localUpdatedAt: Date,
        remoteModifiedAt: Date,
        lastSyncedRemoteModifiedAt: Date?,
        lastSyncedRemoteETag: String?,
        remoteETag: String?
    ) -> Bool {
        guard linkState == .pendingUpload else { return false }

        let remoteChangedSinceLastSync: Bool
        if let lastSyncedRemoteETag, let remoteETag {
            remoteChangedSinceLastSync = lastSyncedRemoteETag != remoteETag
        } else if let lastSyncedRemoteModifiedAt {
            remoteChangedSinceLastSync = remoteModifiedAt > lastSyncedRemoteModifiedAt
        } else {
            remoteChangedSinceLastSync = false
        }
        return !remoteChangedSinceLastSync || localUpdatedAt >= remoteModifiedAt
    }

    private func diagnosticDestination(for task: QuadrantTask) -> TaskCategory {
        switch (task.isImportantQuadrant, task.isUrgent) {
        case (true, true): .notImportantAndNotUrgent
        case (true, false): .urgentButNotImportant
        case (false, true): .importantButNotUrgent
        case (false, false): .importantAndUrgent
        }
    }

    private func resetDiagnosticSteps() {
        diagnosticSteps = SyncDiagnosticStep.allCases.map {
            SyncDiagnosticStepResult(step: $0, status: .pending)
        }
    }

    private func resetDiagnosticLog() {
        diagnosticLog = "FourQuadrants Microsoft To Do 同步诊断\n"
        appendDiagnosticLog("开始：随机生成 \(Self.diagnosticProbeCount) 条测试任务。")
    }

    private func appendDiagnosticLog(_ message: String) {
        let formatter = ISO8601DateFormatter()
        diagnosticLog += "[\(formatter.string(from: Date()))] \(message)\n"
    }

    private func diagnosticFieldSummary(for task: SyncDiagnosticTaskSnapshot) -> String {
        return "importance=\(task.importance.rawValue), manualUrgent=\(task.manualIsUrgent), threshold=\(task.urgentThresholdDays.map(String.init) ?? "nil"), originalThreshold=\(task.originalUrgentThresholdDays.map(String.init) ?? "nil"), originalImportance=\(task.originalImportance?.rawValue ?? "nil"), top=\(task.isTop), due=\(task.dueDateKey ?? "nil"), completed=\(task.isCompleted)"
    }

    private func diagnosticFieldSummary(for task: QuadrantTask) -> String {
        diagnosticFieldSummary(for: SyncDiagnosticTaskSnapshot(task: task))
    }

    private func diagnosticLinkSummary(localTaskID: UUID, profileID: UUID) throws -> String {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let descriptor = FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        guard let link = try context.fetch(descriptor).first else { return "link=missing" }
        let remoteModifiedAt = link.remoteLastModifiedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil"
        return "linkState=\(link.state.rawValue) remoteETag=\(link.remoteETag ?? "nil") remoteModified=\(remoteModifiedAt)"
    }

    private func setDiagnosticStep(_ step: SyncDiagnosticStep, status: SyncDiagnosticStepStatus) {
        guard let index = diagnosticSteps.firstIndex(where: { $0.step == step }) else { return }
        diagnosticSteps[index].status = status
    }

    private func failActiveDiagnosticStep(with message: String) {
        if let runningStep = diagnosticSteps.first(where: { $0.status == .running }) {
            setDiagnosticStep(runningStep.step, status: .failed(message))
        }
    }

    private func removeDiagnosticImport(localTaskID: UUID, profileID: UUID) throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        if let task = try localTask(id: localTaskID) {
            context.delete(task)
        }
        let descriptor = FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate {
            $0.profileIdentifier == profileID && $0.localTaskIdentifier == localTaskID
        })
        for link in try context.fetch(descriptor) {
            context.delete(link)
        }
        try context.save()
    }

    private func makeDiagnosticProbe() -> QuadrantTask {
        let identifier = String(UUID().uuidString.prefix(8))
        let title = ["Review", "Plan", "Focus", "Prepare", "Follow up", "Organize"].randomElement()!
        let note = ["source-check", "cloud-roundtrip", "metadata-audit", "delta-import"].randomElement()!
        let importance = ImportanceLevel.allCases.randomElement()!
        let dueAt = Calendar.current.date(
            byAdding: .day,
            value: Int.random(in: 1 ... 90),
            to: Calendar.current.startOfDay(for: Date())
        )!
        return QuadrantTask(
            title: "[FourQuadrants Sync Probe] \(title) \(identifier)",
            notes: "\(note) \(identifier)",
            dueAt: dueAt,
            completedAt: Bool.random() ? Date() : nil,
            importance: importance,
            isUrgent: Bool.random(),
            urgentThresholdDays: Int.random(in: 1 ... 30),
            originalUrgentThresholdDays: Int.random(in: 1 ... 30),
            originalImportance: ImportanceLevel.allCases.randomElement()!,
            isTop: Bool.random()
        )
    }

    private func cleanUpDiagnostic(
        probes: [QuadrantTask],
        remoteTasks: [MicrosoftTodoTask],
        profile: MicrosoftTodoSyncProfile,
        token: String
    ) async throws {
        for remoteTask in remoteTasks {
            do {
                try await graph.deleteTask(
                    listID: profile.defaultListIdentifier,
                    taskID: remoteTask.id,
                    eTag: remoteTask.eTag,
                    token: token
                )
            } catch let error as MicrosoftGraphError {
                guard isNotFound(error) else { throw error }
            }
        }
        for probe in probes {
            try removeDiagnosticImport(localTaskID: probe.id, profileID: profile.id)
        }
    }

    private func diagnosticMismatches(expected: SyncDiagnosticTaskSnapshot, actual: QuadrantTask) -> [String] {
        var mismatches: [String] = []
        if expected.id != actual.id { mismatches.append("任务标识") }
        if expected.title != actual.title { mismatches.append("标题") }
        if expected.notes != actual.notes { mismatches.append("备注") }
        if expected.importance != actual.importance { mismatches.append("重要性") }
        if expected.manualIsUrgent != actual.manualIsUrgent { mismatches.append("手动紧急") }
        if expected.urgentThresholdDays != actual.urgentThresholdDays { mismatches.append("紧急阈值") }
        if expected.originalUrgentThresholdDays != actual.originalUrgentThresholdDays { mismatches.append("原始紧急阈值") }
        if expected.originalImportance != actual.originalImportance { mismatches.append("原始重要性") }
        if expected.isTop != actual.isTop { mismatches.append("置顶") }
        if expected.dueDateKey != actual.effectiveDueDateKey { mismatches.append("目标日期") }
        if expected.isCompleted != actual.isCompleted { mismatches.append("完成状态") }
        return mismatches
    }

    private func makeLocalTask(from remote: MicrosoftTodoTask) -> QuadrantTask {
        let modifiedAt = parseDate(remote.lastModifiedDateTime) ?? Date()
        let metadata = remote.fourQuadrantsMetadata
        let task = QuadrantTask(
            id: metadata.flatMap { UUID(uuidString: $0.localTaskIdentifier ?? "") } ?? UUID(),
            title: remote.title ?? "",
            notes: remote.body?.content,
            createdAt: parseDate(remote.createdDateTime) ?? modifiedAt,
            updatedAt: modifiedAt,
            dueAt: nil,
            completedAt: remote.status == "completed" ? (parseDate(remote.completedDateTime) ?? modifiedAt) : nil,
            importance: importance(from: remote.importance),
            isUrgent: metadata?.manualIsUrgent ?? false,
            urgentThresholdDays: metadata?.hasUrgentThresholdDays == true ? metadata?.urgentThresholdDays : nil,
            originalUrgentThresholdDays: metadata?.hasOriginalUrgentThresholdDays == true ? metadata?.originalUrgentThresholdDays : nil,
            originalImportance: metadata?.hasOriginalImportance == true ? metadata.flatMap { ImportanceLevel(rawValue: $0.originalImportance ?? "") } : nil,
            isTop: metadata?.isTop ?? false
        )
        task.dueDateKey = dueDateKey(from: remote.dueDateTime)
        task.dueAt = task.dueDateKey.flatMap { TaskDueDate.date(for: $0) }
        return task
    }

    private func update(_ task: QuadrantTask, from remote: MicrosoftTodoTask) {
        let modifiedAt = parseDate(remote.lastModifiedDateTime) ?? Date()
        task.title = remote.title ?? task.title
        task.notes = remote.body?.content
        task.dueDateKey = dueDateKey(from: remote.dueDateTime)
        task.dueAt = task.dueDateKey.flatMap { TaskDueDate.date(for: $0) }
        task.completedAt = remote.status == "completed" ? (parseDate(remote.completedDateTime) ?? modifiedAt) : nil
        task.importance = importance(from: remote.importance)
        if let metadata = remote.fourQuadrantsMetadata {
            task.manualIsUrgent = metadata.manualIsUrgent ?? task.manualIsUrgent
            task.urgentThresholdDays = metadata.hasUrgentThresholdDays == true ? metadata.urgentThresholdDays : nil
            task.originalUrgentThresholdDays = metadata.hasOriginalUrgentThresholdDays == true ? metadata.originalUrgentThresholdDays : nil
            task.originalImportance = metadata.hasOriginalImportance == true ? ImportanceLevel(rawValue: metadata.originalImportance ?? "") : nil
            task.isTop = metadata.isTop ?? task.isTop
        }
        task.updatedAt = modifiedAt
    }

    private func payload(
        for task: QuadrantTask,
        profile: MicrosoftTodoSyncProfile,
        operationIdentifier: UUID? = nil,
        includingMetadata: Bool
    ) -> MicrosoftTodoTaskPayload {
        MicrosoftTodoTaskPayload(
            title: task.title,
            body: .init(content: task.notes ?? ""),
            importance: task.importance.rawValue,
            status: task.isCompleted ? "completed" : "notStarted",
            dueDateTime: task.effectiveDueDateKey.map {
                .init(dueDateKey: $0, timeZoneIdentifier: profile.taskTimeZoneIdentifier)
            },
            extensions: includingMetadata ? [metadata(for: task, operationIdentifier: operationIdentifier)] : nil
        )
    }

    private func metadata(for task: QuadrantTask, operationIdentifier: UUID? = nil) -> MicrosoftTodoTaskMetadata {
        MicrosoftTodoTaskMetadata(
            localTaskIdentifier: task.id.uuidString,
            manualIsUrgent: task.manualIsUrgent,
            urgentThresholdDays: task.urgentThresholdDays,
            originalUrgentThresholdDays: task.originalUrgentThresholdDays,
            originalImportance: task.originalImportance?.rawValue,
            isTop: task.isTop,
            operationIdentifier: operationIdentifier
        )
    }

    private func importance(from remoteValue: String?) -> ImportanceLevel {
        ImportanceLevel(rawValue: remoteValue ?? "") ?? .normal
    }

    private func deltaQueryVersionKey(for profile: MicrosoftTodoSyncProfile) -> String {
        "MicrosoftTodo.taskDeltaQueryVersion.\(profile.id.uuidString)"
    }

    private func restoreCachedAccount() {
        do {
            let app = try makeApplication()
            let accounts = try app.allAccounts()
            currentAccount = accounts.first
            isAuthenticated = currentAccount != nil
            accountName = currentAccount?.username
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    private func acquireInteractiveToken() async throws -> MSALResult {
        let app = try makeApplication()
        let parameters = MSALInteractiveTokenParameters(
            scopes: MSALConfig.scopes,
            webviewParameters: MSALWebviewParameters(authPresentationViewController: try presentationViewController())
        )
        parameters.promptType = .selectAccount
        return try await withCheckedThrowingContinuation { continuation in
            app.acquireToken(with: parameters) { result, error in
                if let error { continuation.resume(throwing: error) }
                else if let result { continuation.resume(returning: result) }
                else { continuation.resume(throwing: SyncError.authenticationFailed) }
            }
        }
    }

    private func acquireSilentToken() async throws -> String {
        guard let account = currentAccount else { throw SyncError.notAuthenticated }
        let app = try makeApplication()
        let parameters = MSALSilentTokenParameters(scopes: MSALConfig.scopes, account: account)
        let result: MSALResult = try await withCheckedThrowingContinuation { continuation in
            app.acquireTokenSilent(with: parameters) { result, error in
                if let error { continuation.resume(throwing: error) }
                else if let result { continuation.resume(returning: result) }
                else { continuation.resume(throwing: SyncError.authenticationFailed) }
            }
        }
        return result.accessToken
    }

    private func makeApplication() throws -> MSALPublicClientApplication {
        if let application { return application }
        let authority = try MSALAADAuthority(url: URL(string: MSALConfig.authority)!)
        let configuration = MSALPublicClientApplicationConfig(clientId: MSALConfig.clientID, redirectUri: MSALConfig.redirectUri, authority: authority)
        // The authority is a fixed Microsoft public-cloud endpoint, so it can be trusted locally.
        // This avoids a separate instance-discovery request before the system web session opens.
        configuration.knownAuthorities = [authority]
        // MSAL defaults to the shared com.microsoft.adalcache group. This app doesn't
        // need cross-app SSO, so keep tokens in this target's private Keychain group.
        // It avoids requiring the Keychain Sharing entitlement on every app variant.
        configuration.cacheConfig.keychainSharingGroup = Bundle.main.bundleIdentifier ?? MSALConfig.bundleID
        let application = try MSALPublicClientApplication(configuration: configuration)
        self.application = application
        return application
    }

    #if os(iOS)
    private func presentationViewController() throws -> UIViewController {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            throw SyncError.presentationUnavailable
        }
        return topPresentationViewController(from: root)
    }

    private func topPresentationViewController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topPresentationViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topPresentationViewController(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topPresentationViewController(from: selected)
        }
        return controller
    }
    #elseif os(macOS)
    private func presentationViewController() throws -> NSViewController {
        guard let controller = MacAuthenticationPresentation.viewController() else {
            throw SyncError.presentationUnavailable
        }
        return controller
    }
    #endif

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        return fallback.date(from: value)
    }

    private func parseDate(_ value: MicrosoftTodoTask.DateTimeValue?) -> Date? {
        guard let value, let dateTime = value.dateTime else { return nil }
        if dateTime.hasSuffix("Z") {
            return parseDate(dateTime)
        }

        let timeZone = value.timeZone
            .map(MicrosoftGraphTimeZone.foundationIdentifier(for:))
            .flatMap(TimeZone.init(identifier:)) ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateTime) { return date }
        }
        return nil
    }

    private func dueDateKey(from value: MicrosoftTodoTask.DateTimeValue?) -> String? {
        guard let dateTime = value?.dateTime,
              dateTime.count >= 10 else { return nil }
        let key = String(dateTime.prefix(10))
        return TaskDueDate.isValid(key) ? key : nil
    }

    private func requiresDeltaReset(_ error: MicrosoftGraphError) -> Bool {
        if case let .httpStatus(status, message) = error {
            return status == 410 || message.localizedCaseInsensitiveContains("syncStateNotFound")
        }
        return false
    }

    private func isNotFound(_ error: MicrosoftGraphError) -> Bool {
        if case let .httpStatus(status, _) = error {
            return status == 404
        }
        return false
    }

    private func deleteLocallyDeletedRemoteTask(_ task: QuadrantTask, link: MicrosoftTodoTaskLink, in context: ModelContext) {
        context.delete(task)
        context.delete(link)
    }

    private func refreshPublishedState() {
        lastSyncTime = activeProfile?.lastSuccessfulSyncAt
    }

    private func saveContext() {
        do { try modelContext?.save() }
        catch { errorMessage = userFacingError(error) }
    }

    private func userFacingError(_ error: Error) -> String {
        if let graphError = error as? MicrosoftGraphError {
            return graphError.errorDescription ?? "Microsoft Graph 请求失败。"
        }
        if containsOfflineError(error) {
            return "无法连接 Microsoft 登录服务。请用 Safari 打开 login.microsoftonline.com，确认当前 Wi-Fi、蜂窝数据或 VPN 没有拦截该网站后重试。"
        }
        let nsError = error as NSError
        if nsError.domain == MSALErrorDomain {
            return "Microsoft 登录令牌失败（\(nsError.code)）：\(nsError.localizedDescription)"
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }
        return "Microsoft To Do 同步失败（\(nsError.domain) \(nsError.code)）：\(nsError.localizedDescription)"
    }

    private func containsOfflineError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorNotConnectedToInternet {
            return true
        }
        return nsError.userInfo.values
            .compactMap { $0 as? NSError }
            .contains { containsOfflineError($0) }
    }

    private enum SyncError: LocalizedError {
        case notConfigured, notAuthenticated, defaultListNotFound, authenticationFailed, presentationUnavailable
        case pendingOperationsFailed(Int)
        case diagnosticImportMissing(String)
        case diagnosticMismatch(String, [String])
        case diagnosticMoveFailed(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured: "同步服务尚未准备好。"
            case .notAuthenticated: "请先连接 Microsoft 帐户。"
            case .defaultListNotFound: "未找到 Microsoft To Do 的默认 Tasks 清单。"
            case .authenticationFailed: "Microsoft 登录没有返回有效令牌。"
            case .presentationUnavailable: "当前无法打开 Microsoft 登录页面。"
            case let .pendingOperationsFailed(count): "有 \(count) 个 Microsoft To Do 变更尚未送达，系统会自动重试。"
            case let .diagnosticImportMissing(title): "同步诊断未能从远端恢复测试任务：\(title)。"
            case let .diagnosticMismatch(title, fields): "同步诊断发现字段不一致：\(title)，\(fields.joined(separator: "、"))。"
            case let .diagnosticMoveFailed(title): "同步诊断未能将测试任务移动到目标象限：\(title)。"
            }
        }
    }
}

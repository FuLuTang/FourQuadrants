import Combine
import Foundation
import MSAL
import SwiftData
import UIKit

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published private(set) var isSyncing = false
    @Published private(set) var isSigningIn = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var isAuthenticated = false
    @Published var errorMessage: String?
    @Published private(set) var accountName: String?
    @Published private(set) var pendingInitialTasks: [QuadrantTask] = []

    var needsInitialMerge: Bool { !pendingInitialTasks.isEmpty }
    var isSyncEnabled: Bool { activeProfile?.isEnabled ?? false }

    private var modelContext: ModelContext?
    private let graph = MicrosoftGraphClient()
    private var application: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?
    private var signInAttemptID: UUID?

    private init() {}

    func configure(modelContext: ModelContext, taskStore: TaskStore) {
        self.modelContext = modelContext
        taskStore.quadrantTaskMutationHandler = { [weak self] mutation in
            self?.record(mutation: mutation)
        }
        restoreCachedAccount()
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
            pendingInitialTasks = try localTasksWithoutLink()
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
                modelContext?.insert(MicrosoftTodoTaskLink(profileIdentifier: profile.id, localTaskIdentifier: task.id, state: state))
            }
            try modelContext?.save()
            pendingInitialTasks = []
            await synchronize()
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    func cancelInitialMerge() {
        pendingInitialTasks = []
    }

    func setSyncEnabled(_ enabled: Bool) {
        guard let profile = activeProfile else { return }
        profile.isEnabled = enabled
        profile.updatedAt = Date()
        saveContext()
        if enabled { Task { await synchronize() } }
    }

    func synchronize() async {
        guard let profile = activeProfile, profile.isEnabled, !isSyncing else { return }
        do {
            isSyncing = true
            defer { isSyncing = false }
            errorMessage = nil
            let token = try await acquireSilentToken()
            try await pullRemoteChanges(profile: profile, token: token)
            try await pushLocalChanges(profile: profile, token: token)
            profile.lastSuccessfulSyncAt = Date()
            profile.updatedAt = Date()
            try modelContext?.save()
            lastSyncTime = profile.lastSuccessfulSyncAt
        } catch let error as MicrosoftGraphError {
            if requiresDeltaReset(error) {
                profile.deltaLink = nil
                saveContext()
                isSyncing = false
                await synchronize()
            } else {
                errorMessage = userFacingError(error)
            }
        } catch {
            errorMessage = userFacingError(error)
        }
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
        var nextURL = profile.deltaLink.flatMap(URL.init(string:))
        var finalDeltaLink: String?
        repeat {
            let page = try await graph.taskDeltaPage(listID: profile.defaultListIdentifier, url: nextURL, token: token)
            try apply(page.value, profile: profile)
            try modelContext?.save()
            nextURL = page.nextLink.flatMap(URL.init(string:))
            finalDeltaLink = page.deltaLink ?? finalDeltaLink
        } while nextURL != nil
        if let finalDeltaLink {
            profile.deltaLink = finalDeltaLink
        }
    }

    private func apply(_ remoteTasks: [MicrosoftTodoTask], profile: MicrosoftTodoSyncProfile) throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let profileIdentifier = profile.id
        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier }))
        let linksByRemoteID = links.reduce(into: [String: MicrosoftTodoTaskLink]()) { result, link in
            if let remoteID = link.remoteTaskIdentifier, result[remoteID] == nil {
                result[remoteID] = link
            }
        }
        let localTasks = try context.fetch(FetchDescriptor<QuadrantTask>())
        let localByID = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })

        for remote in remoteTasks {
            let link = linksByRemoteID[remote.id]
            if remote.removed != nil {
                guard let link else { continue }
                if let task = localByID[link.localTaskIdentifier] { context.delete(task) }
                link.state = .remotelyDeleted
                link.updatedAt = Date()
                continue
            }

            let remoteModifiedAt = parseDate(remote.lastModifiedDateTime) ?? Date()
            if let link, let local = localByID[link.localTaskIdentifier] {
                if link.state == .pendingUpload, local.updatedAt > remoteModifiedAt {
                    continue
                }
                update(local, from: remote)
                link.remoteETag = remote.eTag
                link.remoteLastModifiedAt = remoteModifiedAt
                link.lastSyncedLocalUpdatedAt = local.updatedAt
                link.state = .linked
                link.updatedAt = Date()
            } else {
                let task = makeLocalTask(from: remote)
                context.insert(task)
                context.insert(MicrosoftTodoTaskLink(
                    profileIdentifier: profile.id,
                    localTaskIdentifier: task.id,
                    remoteTaskIdentifier: remote.id,
                    state: .linked
                ))
            }
        }
    }

    private func pushLocalChanges(profile: MicrosoftTodoSyncProfile, token: String) async throws {
        guard let context = modelContext else { throw SyncError.notConfigured }
        let profileIdentifier = profile.id
        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier }))
        let tasks = try context.fetch(FetchDescriptor<QuadrantTask>())
        let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        for link in links where link.state != .linked && link.state != .localOnly && link.state != .remotelyDeleted {
            if link.state == .pendingLocalDeletion, let remoteID = link.remoteTaskIdentifier {
                try await graph.deleteTask(listID: profile.defaultListIdentifier, taskID: remoteID, eTag: link.remoteETag, token: token)
                context.delete(link)
                continue
            }
            guard let task = tasksByID[link.localTaskIdentifier] else { continue }
            let payload = payload(for: task)
            let remote: MicrosoftTodoTask
            if let remoteID = link.remoteTaskIdentifier {
                remote = try await graph.updateTask(listID: profile.defaultListIdentifier, taskID: remoteID, payload: payload, eTag: link.remoteETag, token: token)
            } else {
                remote = try await graph.createTask(listID: profile.defaultListIdentifier, payload: payload, token: token)
            }
            link.remoteTaskIdentifier = remote.id
            link.remoteETag = remote.eTag
            link.remoteLastModifiedAt = parseDate(remote.lastModifiedDateTime)
            link.lastSyncedLocalUpdatedAt = task.updatedAt
            link.state = .linked
            link.updatedAt = Date()
            try context.save()
        }
    }

    private func record(mutation: TaskStore.QuadrantTaskMutation) {
        guard let profile = activeProfile, profile.isEnabled, let context = modelContext else { return }
        do {
            let profileIdentifier = profile.id
            switch mutation {
            case let .upsert(taskID):
                let descriptor = FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier && $0.localTaskIdentifier == taskID })
                if let link = try context.fetch(descriptor).first, link.state != .localOnly {
                    link.state = .pendingUpload
                    link.updatedAt = Date()
                } else if try context.fetch(descriptor).isEmpty {
                    context.insert(MicrosoftTodoTaskLink(profileIdentifier: profile.id, localTaskIdentifier: taskID))
                }
            case let .delete(taskID):
                let descriptor = FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier && $0.localTaskIdentifier == taskID })
                if let link = try context.fetch(descriptor).first, link.remoteTaskIdentifier != nil {
                    link.state = .pendingLocalDeletion
                    link.updatedAt = Date()
                }
            }
            try context.save()
            Task { await self.synchronize() }
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    private func localTasksWithoutLink() throws -> [QuadrantTask] {
        guard let context = modelContext, let profile = activeProfile else { return [] }
        let profileIdentifier = profile.id
        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>(predicate: #Predicate { $0.profileIdentifier == profileIdentifier }))
        let linkedIDs = Set(links.map(\.localTaskIdentifier))
        return try context.fetch(FetchDescriptor<QuadrantTask>()).filter { !linkedIDs.contains($0.id) }
    }

    private func makeLocalTask(from remote: MicrosoftTodoTask) -> QuadrantTask {
        let modifiedAt = parseDate(remote.lastModifiedDateTime) ?? Date()
        return QuadrantTask(
            title: remote.title ?? "",
            notes: remote.body?.content,
            createdAt: parseDate(remote.createdDateTime) ?? modifiedAt,
            updatedAt: modifiedAt,
            dueAt: parseDate(remote.dueDateTime?.dateTime),
            completedAt: remote.status == "completed" ? (parseDate(remote.completedDateTime?.dateTime) ?? modifiedAt) : nil,
            importance: remote.importance == "high" ? .high : .normal,
            isUrgent: false
        )
    }

    private func update(_ task: QuadrantTask, from remote: MicrosoftTodoTask) {
        let modifiedAt = parseDate(remote.lastModifiedDateTime) ?? Date()
        task.title = remote.title ?? task.title
        task.notes = remote.body?.content
        task.dueAt = parseDate(remote.dueDateTime?.dateTime)
        task.completedAt = remote.status == "completed" ? (parseDate(remote.completedDateTime?.dateTime) ?? modifiedAt) : nil
        task.importance = remote.importance == "high" ? .high : .normal
        task.manualIsUrgent = false
        task.updatedAt = modifiedAt
    }

    private func payload(for task: QuadrantTask) -> MicrosoftTodoTaskPayload {
        MicrosoftTodoTaskPayload(
            title: task.title,
            body: .init(content: task.notes ?? ""),
            importance: task.importance == .high ? "high" : "normal",
            status: task.isCompleted ? "completed" : "notStarted",
            dueDateTime: task.dueAt.map { .init(dateTime: ISO8601DateFormatter().string(from: $0)) }
        )
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

    private func requiresDeltaReset(_ error: MicrosoftGraphError) -> Bool {
        if case let .httpStatus(status, message) = error {
            return status == 410 || message.localizedCaseInsensitiveContains("syncStateNotFound")
        }
        return false
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
        var errorDescription: String? {
            switch self {
            case .notConfigured: "同步服务尚未准备好。"
            case .notAuthenticated: "请先连接 Microsoft 帐户。"
            case .defaultListNotFound: "未找到 Microsoft To Do 的默认 Tasks 清单。"
            case .authenticationFailed: "Microsoft 登录没有返回有效令牌。"
            case .presentationUnavailable: "当前无法打开 Microsoft 登录页面。"
            }
        }
    }
}

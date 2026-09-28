import MSAL
import SwiftData
import SwiftUI

enum WidgetRoute: Equatable {
    case today
    case quadrant(TaskCategory)
    case task(UUID)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "fourquadrants" else { return nil }
        // `fourquadrants://task/<id>` stores `task` in the host and the ID in
        // the path. Accept the slash-only form as well for hand-authored URLs.
        let components = ([url.host].compactMap { $0 } + url.pathComponents.filter { $0 != "/" })
        guard let kind = components.first else { return nil }
        switch kind {
        case "today":
            self = .today
        case "quadrant":
            guard components.count > 1, let category = TaskCategory(rawValue: components[1]), category != .all, category != .completed else { return nil }
            self = .quadrant(category)
        case "task":
            guard components.count > 1, let id = UUID(uuidString: components[1]) else { return nil }
            self = .task(id)
        default:
            return nil
        }
    }
}

extension Notification.Name {
    static let widgetRoute = Notification.Name("FourQuadrants.widgetRoute")
}

@main
struct FourQuadrantsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appData = AppDataController()

    var body: some Scene {
        WindowGroup {
            switch appData.state {
            case .loading:
                ProgressView()
            case .ready(let session):
                MainView()
                    .modelContainer(session.container)
                    .environment(session.taskStore)
                    .onOpenURL { url in
                        if let route = WidgetRoute(url: url) {
                            NotificationCenter.default.post(name: .widgetRoute, object: route)
                        }
                        MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                    }
                    .task {
                        _ = AppLifecycleManager.shared.performUpdateIfNeeded()
                        requestNotificationPermission()
                    }
            case .recoveryRequired(let error):
                DataStoreRecoveryView(
                    error: error,
                    retry: appData.retry,
                    reset: appData.resetLocalData
                )
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
}

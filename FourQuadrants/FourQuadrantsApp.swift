import MSAL
import SwiftData
import SwiftUI

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

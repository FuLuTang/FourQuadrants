import AppKit
import SwiftData
import SwiftUI

extension Notification.Name {
    static let macCreateTask = Notification.Name("FourQuadrantsMac.createTask")
    static let macShowTask = Notification.Name("FourQuadrantsMac.showTask")
    static let macNavigate = Notification.Name("FourQuadrantsMac.navigate")
}

@main
struct FourQuadrantsMacApp: App {
    @NSApplicationDelegateAdaptor(MacApplicationDelegate.self) private var delegate
    @State private var runtime = MacApplicationRuntime()

    var body: some Scene {
        Window("四象限", id: "main") {
            MacRootView(runtime: runtime)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1240, height: 820)
        .commands {
            SidebarCommands()
            CommandGroup(after: .newItem) {
                Button("新建任务") {
                    NotificationCenter.default.post(name: .macCreateTask, object: nil)
                }
                .keyboardShortcut("n")
                .disabled(runtime.stickies == nil)
            }
            CommandMenu("便笺") {
                Button("新建桌面便笺") {
                    runtime.stickies?.pinTasks([], title: "新便笺")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(runtime.stickies == nil)
                Button("管理桌面便笺") {
                    NotificationCenter.default.post(name: .macNavigate, object: "stickies")
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }

        Settings {
            MacSettingsRootView(runtime: runtime)
        }
    }
}

final class MacApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MacRootView: View {
    let runtime: MacApplicationRuntime
    @Environment(\.openWindow) private var openWindow
    @AppStorage("themeMode") private var themeMode = 0

    var body: some View {
        MacSessionContent(runtime: runtime)
            .preferredColorScheme(themeMode == 1 ? .light : themeMode == 2 ? .dark : nil)
            .onReceive(NotificationCenter.default.publisher(for: .macShowTask)) { _ in
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .macNavigate)) { _ in
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .onOpenURL { url in
                guard url.scheme == "fourquadrants", url.host == "task",
                      let id = UUID(uuidString: url.lastPathComponent) else { return }
                NotificationCenter.default.post(name: .macShowTask, object: id)
            }
    }
}

private struct MacSessionContent: View {
    let runtime: MacApplicationRuntime

    var body: some View {
        if let data = runtime.data {
            switch data.state {
            case .loading:
                ProgressView("正在打开任务…")
            case .ready(let session):
                if let stickies = runtime.stickies {
                    MacWorkspaceView()
                        .modelContainer(session.container)
                        .environment(session.taskStore)
                        .environment(stickies)
                        .task { runtime.restoreWindowsIfNeeded() }
                }
            case .recoveryRequired(let error):
                MacRecoveryView(error: error, retry: runtime.retry, reset: runtime.reset)
            }
        } else {
            ContentUnavailableView("无法准备演示数据", systemImage: "externaldrive.badge.exclamationmark", description: Text(runtime.initializationError ?? "请重新打开应用。"))
        }
    }
}

private struct MacSettingsRootView: View {
    let runtime: MacApplicationRuntime
    @AppStorage("themeMode") private var themeMode = 0

    var body: some View {
        if let data = runtime.data, case .ready(let session) = data.state,
           let stickies = runtime.stickies {
            MacSettingsView()
                .modelContainer(session.container)
                .environment(session.taskStore)
                .environment(stickies)
                .preferredColorScheme(themeMode == 1 ? .light : themeMode == 2 ? .dark : nil)
        } else {
            ContentUnavailableView("任务数据暂不可用", systemImage: "externaldrive.badge.exclamationmark")
                .frame(width: 480, height: 300)
        }
    }
}

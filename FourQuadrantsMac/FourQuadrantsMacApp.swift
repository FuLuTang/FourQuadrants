import AppKit
import SwiftData
import SwiftUI

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
        .commands { MacCommands(runtime: runtime) }

        Settings {
            MacSettingsRootView(runtime: runtime)
        }

        MenuBarExtra {
            MacMenuBarContent(runtime: runtime)
        } label: {
            MacMenuBarLabel(runtime: runtime)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The status item label is alive for the whole app lifetime, unlike the main
/// window, so it hands `openWindow` to the runtime for AppKit-originated routes.
private struct MacMenuBarLabel: View {
    let runtime: MacApplicationRuntime
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Label("FourQuadrants", systemImage: "square.grid.2x2.fill")
            .task { registerOpener(runtime: runtime, openWindow: openWindow) }
    }
}

@MainActor
private func registerOpener(runtime: MacApplicationRuntime, openWindow: OpenWindowAction) {
    runtime.registerMainWindowOpener {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MacMenuBarContent: View {
    let runtime: MacApplicationRuntime
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("新建任务", systemImage: "plus") {
            runtime.requestNewTask()
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("打开四象限", systemImage: "macwindow") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Menu("添加ToDo便笺浮窗", systemImage: "note.text.badge.plus") {
            MacStickyCreationMenuItems(stickies: runtime.stickies)
        }
        .disabled(runtime.stickies == nil)

        if let stickies = runtime.stickies, !stickies.configurations.isEmpty {
            Menu("已有ToDo便笺", systemImage: "square.on.square") {
                ForEach(stickies.configurations) { configuration in
                    Button {
                        if configuration.isVisible {
                            stickies.hideWindow(id: configuration.id)
                        } else {
                            stickies.showWindow(for: configuration.id)
                        }
                    } label: {
                        Label {
                            MacStickyConfigurationHeading(configuration: configuration)
                        } icon: {
                            Image(systemName: configuration.isVisible ? "checkmark" : "eye.slash")
                        }
                    }
                }
            }
        }
        Divider()
        Button("设置…", systemImage: "gearshape") { openSettings() }
        Button("退出 FourQuadrants", systemImage: "power") { NSApp.terminate(nil) }
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
            .environment(runtime)
            .preferredColorScheme(themeMode == 1 ? .light : themeMode == 2 ? .dark : nil)
            .task { registerOpener(runtime: runtime, openWindow: openWindow) }
            .onOpenURL { runtime.handle(url: $0) }
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
                } else {
                    ContentUnavailableView {
                        Label("便笺服务未就绪", systemImage: "note.text")
                    } description: {
                        Text("任务数据已打开，但桌面便笺尚未准备好。")
                    } actions: {
                        Button("重新连接", action: runtime.reconnectWindows)
                            .buttonStyle(.borderedProminent)
                    }
                }
            case .recoveryRequired(let error):
                MacRecoveryView(error: error, retry: runtime.retry, reset: runtime.reset)
            }
        } else {
            ContentUnavailableView("无法准备演示数据", systemImage: "externaldrive.badge.exclamationmark", description: runtime.initializationError.map { Text(verbatim: $0) } ?? Text("请重新打开应用。"))
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

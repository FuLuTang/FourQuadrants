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
            CommandMenu("ToDo便笺") {
                Menu("添加ToDo便笺浮窗") {
                    ForEach([
                        TaskCategory.importantAndUrgent,
                        .urgentButNotImportant,
                        .importantButNotUrgent,
                        .notImportantAndNotUrgent
                    ], id: \.self) { category in
                        Button {
                            runtime.stickies?.createNote(source: .category(category))
                        } label: {
                            MacQuadrantHeading(category: category, font: .body)
                        }
                    }
                    Divider()
                    Button("四合一") { runtime.stickies?.createNote(source: .combined) }
                    Button("智能排列") { runtime.stickies?.createNote(source: .smart) }
                }
                .disabled(runtime.stickies == nil)
            }
        }

        Settings {
            MacSettingsRootView(runtime: runtime)
        }

        MenuBarExtra("FourQuadrants", systemImage: "square.grid.2x2.fill") {
            MacMenuBarContent(runtime: runtime)
        }
        .menuBarExtraStyle(.menu)
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
            ForEach([
                TaskCategory.importantAndUrgent,
                .urgentButNotImportant,
                .importantButNotUrgent,
                .notImportantAndNotUrgent
            ], id: \.self) { category in
                Button {
                    runtime.stickies?.createNote(source: .category(category))
                } label: {
                    MacQuadrantHeading(category: category, font: .body)
                }
            }
            Divider()
            Button("四合一") { runtime.stickies?.createNote(source: .combined) }
            Button("智能排列") { runtime.stickies?.createNote(source: .smart) }
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

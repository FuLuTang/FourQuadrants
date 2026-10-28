import AppKit

/// 便笺标题条的 AppKit 菜单。标题条背景是 NSView，用原生 NSMenu 响应右键最可靠。
@MainActor
enum MacStickyMenu {
    /// 六模式菜单：点击分类名与右键菜单共用。
    static func modeItems(current: MacStickyMode, coordinator: MacStickyCoordinator, id: UUID) -> [NSMenuItem] {
        MacStickyMode.allCases.map { mode in
            let item = ClosureMenuItem(title: mode.title) { [weak coordinator] in
                coordinator?.setSource(mode.source, for: id)
            }
            item.state = mode == current ? .on : .off
            return item
        }
    }

    static func modeMenu(configuration: MacStickyConfiguration, coordinator: MacStickyCoordinator) -> NSMenu {
        let menu = NSMenu()
        modeItems(current: MacStickyMode(source: configuration.source), coordinator: coordinator, id: configuration.id)
            .forEach(menu.addItem)
        return menu
    }

    /// 完整菜单：六模式、显示详情、置顶、删除浮窗配置。
    static func fullMenu(configuration: MacStickyConfiguration, coordinator: MacStickyCoordinator) -> NSMenu {
        let id = configuration.id
        let menu = NSMenu()
        modeItems(current: MacStickyMode(source: configuration.source), coordinator: coordinator, id: id)
            .forEach(menu.addItem)
        menu.addItem(.separator())

        let details = ClosureMenuItem(title: "显示任务详情") { [weak coordinator] in
            coordinator?.setShowDetails(!configuration.showDetails, id: id)
        }
        details.state = configuration.showDetails ? .on : .off
        menu.addItem(details)

        let floating = ClosureMenuItem(title: "保持在其他窗口上方") { [weak coordinator] in
            coordinator?.setFloating(!configuration.isFloating, id: id)
        }
        floating.state = configuration.isFloating ? .on : .off
        menu.addItem(floating)

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "删除此浮窗配置") { [weak coordinator] in
            coordinator?.removeConfiguration(id: id)
        })
        return menu
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() { handler() }
}

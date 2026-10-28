import AppKit
import SwiftData
import SwiftUI

/// 点击不激活本应用的便笺面板，行为接近小组件。
@MainActor
private final class MacStickyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 让第一次点击直接生效，而不是只用来聚焦窗口。
private final class MacStickyHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// 管理一张便笺的 AppKit 面板：创建、显示、层级与几何。内容全部由 SwiftUI 负责。
@MainActor
final class MacStickyPanelController: NSObject, NSWindowDelegate {
    private let panel: MacStickyPanel
    private weak var coordinator: MacStickyCoordinator?
    private let configurationID: UUID
    private var isClosing = false

    init(configuration: MacStickyConfiguration, coordinator: MacStickyCoordinator, container: ModelContainer) {
        configurationID = configuration.id
        self.coordinator = coordinator
        let frame = configuration.frame.windowFrame(isCollapsed: configuration.isCollapsed)
        panel = MacStickyPanel(
            contentRect: NSRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        let hostingView = MacStickyHostingView(
            rootView: MacStickyNoteView(configurationID: configuration.id)
                .modelContainer(container)
                .environment(coordinator)
        )
        // 窗口尺寸完全由配置决定，不让 SwiftUI 的内容尺寸反过来约束 16pt 的收起态。
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        apply(configuration)
        panel.delegate = self
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func close() {
        guard !isClosing else { return }
        isClosing = true
        panel.delegate = nil
        panel.orderOut(nil)
        panel.contentView = nil
        panel.close()
    }

    /// 把配置同步到面板：层级、可调整尺寸、最小尺寸与框架。无动画，立即生效。
    func apply(_ configuration: MacStickyConfiguration) {
        guard !isClosing else { return }
        panel.level = configuration.isFloating ? .floating : .normal
        if configuration.isCollapsed {
            panel.styleMask.remove(.resizable)
            panel.minSize = NSSize(width: MacStickyLayout.minimumSize.width, height: MacStickyLayout.titleBarHeight)
        } else {
            panel.styleMask.insert(.resizable)
            panel.minSize = NSSize(width: MacStickyLayout.minimumSize.width, height: MacStickyLayout.minimumSize.height)
        }
        let target = configuration.frame.windowFrame(isCollapsed: configuration.isCollapsed)
        let targetRect = NSRect(x: target.x, y: target.y, width: target.width, height: target.height)
        if panel.frame != targetRect {
            panel.setFrame(targetRect, display: true, animate: false)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        coordinator?.hideWindow(id: configurationID)
        return false
    }

    func windowDidMove(_ notification: Notification) {
        coordinator?.recordWindowFrame(panel.frame, id: configurationID)
    }

    func windowDidResize(_ notification: Notification) {
        coordinator?.recordWindowFrame(panel.frame, id: configurationID)
    }
}

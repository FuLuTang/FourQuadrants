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
    /// 收起/展开动画的代次；`isAnimatingFrame` 为 true 时窗口回报的中间 frame 不写入配置。
    private var animationGeneration = 0
    private var isAnimatingFrame = false

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

    /// 把配置同步到面板：层级、可调整尺寸、最小尺寸与框架。默认立即生效；收起/展开传 `animated`，只让窗口 frame 做动画。
    func apply(_ configuration: MacStickyConfiguration, animated: Bool = false) {
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
        // 无论是否动画，先作废进行中的动画；之后的 frame 变化都以这次目标为准。
        animationGeneration += 1
        let generation = animationGeneration
        guard panel.frame != targetRect else {
            isAnimatingFrame = false
            return
        }
        guard animated, panel.isVisible else {
            isAnimatingFrame = false
            panel.setFrame(targetRect, display: true, animate: false)
            return
        }
        // 只动下边界：目标框架由配置推导，上边界、左边界、宽度本来就不变。
        isAnimatingFrame = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = MacStickyLayout.collapseAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetRect, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // 被更新的动画取代时不处理，由最新一次负责收尾。
                guard let self, !self.isClosing, generation == self.animationGeneration else { return }
                self.panel.setFrame(targetRect, display: true, animate: false)
                self.isAnimatingFrame = false
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        coordinator?.hideWindow(id: configurationID)
        return false
    }

    func windowDidMove(_ notification: Notification) {
        guard !isAnimatingFrame else { return }
        coordinator?.recordWindowFrame(panel.frame, id: configurationID)
    }

    func windowDidResize(_ notification: Notification) {
        guard !isAnimatingFrame else { return }
        coordinator?.recordWindowFrame(panel.frame, id: configurationID)
    }
}

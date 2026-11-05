import AppKit
import SwiftData
import SwiftUI

// MARK: - 标题条

struct MacStickyTitleBar: View {
    let configuration: MacStickyConfiguration
    let source: MacStickySource
    /// 仅收起态显示未完成数量。
    let openCount: Int?
    @Environment(MacStickyCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            MacStickyDragArea(
                onDoubleClick: { coordinator.setCollapsed(!configuration.isCollapsed, id: configuration.id) },
                menuProvider: { currentFullMenu() }
            )
            HStack(spacing: 0) {
                controlBox(label: "隐藏浮窗") { coordinator.hideWindow(id: configuration.id) }
                modeButton
                Spacer(minLength: 0)
                controlBox(label: configuration.isCollapsed ? "展开任务列表" : "收起为标题条", showsShade: true) {
                    coordinator.setCollapsed(!configuration.isCollapsed, id: configuration.id)
                }
            }
            .padding(.horizontal, MacStickyLayout.titleBarEdgeInset)
        }
        .frame(height: MacStickyLayout.titleBarHeight)
        .background(source.barColor)
    }

    /// 8pt 空心方框，外围 20×16 为点击区域；整体向内缩进，避开窗口边缘的缩放热区。收起框内多一道横线，与关闭框区分。
    private func controlBox(label: LocalizedStringKey, showsShade: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Rectangle()
                .strokeBorder(MacStickyPalette.ink.opacity(0.55), lineWidth: 1)
                .overlay(alignment: .top) {
                    if showsShade {
                        Rectangle()
                            .fill(MacStickyPalette.ink.opacity(0.55))
                            .frame(height: 1)
                            .padding(.top, 3)
                    }
                }
                .frame(width: 8, height: 8)
                .frame(width: 20, height: MacStickyLayout.titleBarHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var modeButton: some View {
        Button {
            guard let event = NSApp.currentEvent, let view = event.window?.contentView else { return }
            let menu = MacStickyMenu.modeMenu(configuration: currentConfiguration, coordinator: coordinator)
            // 锚点取点击的横向位置与标题条底边：菜单从分类名下方弹出，当前项对齐到锚点。
            let point = view.convert(event.locationInWindow, from: nil)
            let bottomY = view.isFlipped ? MacStickyLayout.titleBarHeight : view.bounds.height - MacStickyLayout.titleBarHeight
            _ = menu.popUp(positioning: menu.items.first { $0.state == .on }, at: NSPoint(x: point.x, y: bottomY), in: view)
        } label: {
            HStack(spacing: 0) {
                if let category = source.category {
                    MacQuadrantHeading(category: category, font: .system(size: 10))
                } else {
                    Text(source.title).font(.system(size: 10))
                }
                if let openCount {
                    Text(" · \(openCount)").font(.system(size: 10)).monospacedDigit()
                }
            }
            .lineLimit(1)
            .foregroundStyle(MacStickyPalette.ink.opacity(0.8))
            .padding(.horizontal, 4)
            .frame(height: MacStickyLayout.titleBarHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("选择 ToDo便笺分类")
        .accessibilityLabel(source.title)
        .accessibilityHint("选择要显示的 ToDo便笺分类")
    }

    private var currentConfiguration: MacStickyConfiguration {
        coordinator.configurations.first { $0.id == configuration.id } ?? configuration
    }

    private func currentFullMenu() -> NSMenu {
        MacStickyMenu.fullMenu(configuration: currentConfiguration, coordinator: coordinator)
    }
}

/// 标题条背景：拖动移动窗口、双击切换收起、右键弹出完整菜单。按钮叠在它上面。
private struct MacStickyDragArea: NSViewRepresentable {
    let onDoubleClick: () -> Void
    let menuProvider: () -> NSMenu?

    func makeNSView(context: Context) -> MacStickyDragView {
        MacStickyDragView(onDoubleClick: onDoubleClick, menuProvider: menuProvider)
    }

    func updateNSView(_ nsView: MacStickyDragView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
        nsView.menuProvider = menuProvider
    }
}

private final class MacStickyDragView: NSView {
    var onDoubleClick: () -> Void
    var menuProvider: () -> NSMenu?

    init(onDoubleClick: @escaping () -> Void, menuProvider: @escaping () -> NSMenu?) {
        self.onDoubleClick = onDoubleClick
        self.menuProvider = menuProvider
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick()
        } else {
            window?.performDrag(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? { menuProvider() }
}

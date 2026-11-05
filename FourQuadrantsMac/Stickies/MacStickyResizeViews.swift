import AppKit
import SwiftData
import SwiftUI

/// 右下角 10pt 缩放热区：无边框面板的边缘缩放热区很窄，这里补一个稳妥的抓取点。
struct MacStickyResizeCorner: NSViewRepresentable {
    func makeNSView(context: Context) -> MacStickyResizeView { MacStickyResizeView() }
    func updateNSView(_ nsView: MacStickyResizeView, context: Context) {}
}

final class MacStickyResizeView: NSView {
    private var startMouse = NSPoint.zero
    private var startFrame = NSRect.zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startMouse = NSEvent.mouseLocation
        startFrame = window.frame
    }

    /// 左边界与上边界保持不变，只改变宽高。
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let width = max(window.minSize.width, startFrame.width + mouse.x - startMouse.x)
        let height = max(window.minSize.height, startFrame.height - (mouse.y - startMouse.y))
        window.setFrame(NSRect(x: startFrame.minX, y: startFrame.maxY - height, width: width, height: height), display: true)
    }
}

/// 四边与四角的缩放光标：铺满窗口但不拦截点击，只用 tracking area 在边缘热区内换光标。
/// `.activeAlways` 保证非激活的面板也能显示；热区宽度与系统对无边框面板的边缘缩放热区一致（约 5pt）。
struct MacStickyResizeCursors: NSViewRepresentable {
    func makeNSView(context: Context) -> MacStickyResizeCursorView { MacStickyResizeCursorView() }
    func updateNSView(_ nsView: MacStickyResizeCursorView, context: Context) {}
}

final class MacStickyResizeCursorView: NSView {
    /// 边缘热区宽度；角落热区边长与右下角缩放把手一致。
    private static let edge: CGFloat = 5
    private static let corner: CGFloat = 10

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let e = Self.edge, c = Self.corner, w = bounds.width, h = bounds.height
        guard w > 2 * c, h > 2 * c else { return }
        // 坐标系非翻转：原点在左下。
        let zones: [(NSRect, NSCursor.FrameResizePosition)] = [
            (NSRect(x: c, y: 0, width: w - 2 * c, height: e), .bottom),
            (NSRect(x: c, y: h - e, width: w - 2 * c, height: e), .top),
            (NSRect(x: 0, y: c, width: e, height: h - 2 * c), .left),
            (NSRect(x: w - e, y: c, width: e, height: h - 2 * c), .right),
            (NSRect(x: 0, y: 0, width: c, height: c), .bottomLeft),
            (NSRect(x: w - c, y: 0, width: c, height: c), .bottomRight),
            (NSRect(x: 0, y: h - c, width: c, height: c), .topLeft),
            (NSRect(x: w - c, y: h - c, width: c, height: c), .topRight),
        ]
        for (rect, position) in zones {
            addTrackingArea(NSTrackingArea(
                rect: rect,
                options: [.cursorUpdate, .activeAlways],
                owner: self,
                userInfo: ["position": position.rawValue]
            ))
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        guard let raw = event.trackingArea?.userInfo?["position"] as? UInt,
              let position = NSCursor.FrameResizePosition(rawValue: raw) else {
            super.cursorUpdate(with: event)
            return
        }
        NSCursor.frameResize(position: position, directions: .all).set()
    }
}


import SwiftUI
import UIKit

struct TimeGridGesture: UIViewRepresentable {
    var minDuration: TimeInterval = 0.5
    
    // 回调闭包
    var onBegan: (CGPoint) -> Void
    var onChanged: (CGPoint) -> Void
    var onEnded: (CGPoint) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear // 透明
        
        let gesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleGesture(_:)))
        gesture.minimumPressDuration = minDuration
        gesture.delegate = context.coordinator // 关键：处理手势共存
        view.addGestureRecognizer(gesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TimeGridGesture
        
        init(parent: TimeGridGesture) {
            self.parent = parent
        }
        
        @objc func handleGesture(_ gesture: UILongPressGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            
            switch gesture.state {
            case .began:
                // 震动反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                parent.onBegan(point)
            case .changed:
                parent.onChanged(point)
            case .ended, .cancelled, .failed:
                parent.onEnded(point)
            default:
                break
            }
        }
        
        // MARK: - 核心：解决滚动冲突
        // 允许长按手势和 ScrollView 的滑动手势“同时识别”
        // 但是！一旦长按触发(.began)，ScrollView 就会被系统自动抑制（这是我们想要的）
        // 在长按触发前，ScrollView 依然可以自由滑动
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true 
        }
    }
}

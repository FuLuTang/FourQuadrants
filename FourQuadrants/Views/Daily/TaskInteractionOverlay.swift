import SwiftUI
import UIKit

struct TaskInteractionOverlay: UIViewRepresentable {
    @Binding var isEditing: Bool
    var onMove: (CGFloat) -> Void
    var onResizeTop: (CGFloat) -> Void
    var onResizeBottom: (CGFloat) -> Void
    var onEnd: () -> Void
    var onSelect: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        // 1. Pan Gesture for Moving and Resizing
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        
        // 2. Long Press to start moving/editing
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        longPress.delegate = context.coordinator
        view.addGestureRecognizer(longPress)
        
        // 3. Tap for selection
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TaskInteractionOverlay
        private var dragMode: DragMode = .none
        private var initialLocation: CGPoint = .zero

        enum DragMode {
            case none
            case move
            case resizeTop
            case resizeBottom
        }

        init(_ parent: TaskInteractionOverlay) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            parent.onSelect()
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            
            switch gesture.state {
            case .began:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    parent.isEditing = true
                }
                // Determine drag mode based on hit zone
                let height = gesture.view?.bounds.height ?? 0
                if location.y < 20 {
                    dragMode = .resizeTop
                } else if location.y > height - 20 {
                    dragMode = .resizeBottom
                } else {
                    dragMode = .move
                }
            case .ended, .cancelled, .failed:
                if dragMode == .none {
                    dragMode = .none
                }
            default:
                break
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            
            switch gesture.state {
            case .began:
                initialLocation = gesture.location(in: gesture.view)
                // If not already in a mode from long press, check if we should start moving
                if dragMode == .none && parent.isEditing {
                    let height = gesture.view?.bounds.height ?? 0
                    if initialLocation.y < 20 {
                        dragMode = .resizeTop
                    } else if initialLocation.y > height - 20 {
                        dragMode = .resizeBottom
                    } else {
                        dragMode = .move
                    }
                }
            case .changed:
                guard dragMode != .none else { return }
                
                switch dragMode {
                case .move:
                    parent.onMove(translation.y)
                case .resizeTop:
                    parent.onResizeTop(translation.y)
                case .resizeBottom:
                    parent.onResizeBottom(translation.y)
                case .none:
                    break
                }
            case .ended, .cancelled, .failed:
                dragMode = .none
                parent.onEnd()
            default:
                break
            }
        }

        // Allow gestures to coexist with ScrollView and each other
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if dragMode != .none {
                return false // Lock scroll when active dragging
            }
            return true
        }
    }
}

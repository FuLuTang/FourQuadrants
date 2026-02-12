import SwiftUI
import UIKit

struct NativeEditMenu: UIViewRepresentable {
    var actions: [NativeMenuAction]
    @Binding var isPresented: Bool
    
    func makeUIView(context: Context) -> NativeEditMenuCallbackView {
        let view = NativeEditMenuCallbackView()
        context.coordinator.view = view
        view.coordinator = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: NativeEditMenuCallbackView, context: Context) {
        context.coordinator.actions = actions
        
        if isPresented {
            uiView.presentMenu()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    struct NativeMenuAction {
        let title: String
        let action: () -> Void
        let style: MenuActionStyle
        
        enum MenuActionStyle {
            case standard
            case destructive
        }
    }
    
    class Coordinator: NSObject, UIEditMenuInteractionDelegate {
        var parent: NativeEditMenu
        var view: NativeEditMenuCallbackView?
        var actions: [NativeMenuAction] = []
        
        init(parent: NativeEditMenu) {
            self.parent = parent
        }
        
        // MARK: - UIEditMenuInteractionDelegate
        
        func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
            
            var menuElements: [UIMenuElement] = []
            
            for actionItem in actions {
                let action = UIAction(title: actionItem.title, attributes: actionItem.style == .destructive ? .destructive : []) { _ in
                    actionItem.action()
                    // Dispatch to main thread to close binding
                    DispatchQueue.main.async {
                        self.parent.isPresented = false
                    }
                }
                menuElements.append(action)
            }
            
            return UIMenu(children: menuElements)
        }
        
        func editMenuInteraction(_ interaction: UIEditMenuInteraction, willDismissMenuFor configuration: UIEditMenuConfiguration, animator: UIEditMenuInteractionAnimating) {
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }
    }
}

class NativeEditMenuCallbackView: UIView {
    weak var coordinator: NativeEditMenu.Coordinator?
    private var interaction: UIEditMenuInteraction?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
        
        let interaction = UIEditMenuInteraction(delegate: self)
        self.addInteraction(interaction)
        self.interaction = interaction
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func presentMenu() {
        guard let interaction = interaction else { return }
        let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: CGPoint(x: bounds.midX, y: 0))
        interaction.presentEditMenu(with: config)
    }
}



extension NativeEditMenuCallbackView: UIEditMenuInteractionDelegate {
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        return coordinator?.editMenuInteraction(interaction, menuFor: configuration, suggestedActions: suggestedActions)
    }
    
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, willDismissMenuFor configuration: UIEditMenuConfiguration, animator: UIEditMenuInteractionAnimating) {
        coordinator?.editMenuInteraction(interaction, willDismissMenuFor: configuration, animator: animator)
    }
}

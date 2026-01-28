import SwiftUI

struct OverviewView: View {
    let category: TaskCategory
    @ObservedObject var taskManager: TaskManager
    var onZoom: ((TaskCategory) -> Void)? = nil
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label {
                    Text(category.displayName)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                } icon: {
                    Image(systemName: category.icon)
                }
                .foregroundColor(category.themeColor)
                
                Spacer()
                
                Button {
                    onZoom?(category)
                } label: {
                    Image(systemName: "plus.screen.fill")
                        .font(.system(size: 12))
                        .padding(6)
                        .background(category.themeColor.opacity(0.15))
                        .foregroundColor(category.themeColor)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppTheme.Padding.standard)
            .padding(.vertical, 8)
            
            // Task List Snippet
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if filteredTasks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary.opacity(0.3))
                                Text("暂无任务")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                        } else {
                            ForEach(filteredTasks) { task in
                                TaskRow(task: task) {
                                    taskManager.toggleTask(task)
                                }
                                .onDrag {
                                    NSItemProvider(object: task.id.uuidString as NSString)
                                }
                                
                                if task.id != filteredTasks.last?.id {
                                    Divider()
                                        .padding(.horizontal, 12)
                                        .opacity(0.3)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .background(
            ZStack {
                // 微光效果 - iOS 26 Dynamic Glow
                Circle()
                    .fill(category.themeColor.opacity(0.2))
                    .blur(radius: 50)
                    .offset(x: -40, y: -40)
                    .scaleEffect(isTargeted ? 1.2 : 1.0) // Pulse when targeted
            }
        )
        .holographicCard()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .stroke(isTargeted ? category.themeColor : Color.clear, lineWidth: 2)
                .shadow(color: isTargeted ? category.themeColor.opacity(0.5) : .clear, radius: 8)
        )
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTargeted)
        .onDrop(of: ["public.text"], isTargeted: $isTargeted, perform: { providers -> Bool in
            if let provider = providers.first {
                provider.loadObject(ofClass: NSString.self) { (nsString, error) in
                    if let idString = nsString as? String,
                       let uuid = UUID(uuidString: idString) {
                        DispatchQueue.main.async {
                            if let draggedTask = taskManager.tasks.first(where: { $0.id == uuid }) {
                                taskManager.dragTaskChangeCategory(task: draggedTask, targetCategory: self.category)
                            }
                        }
                    }
                }
                return true
            }
            return false
        })
    }
    
    var filteredTasks: [QuadrantTask] {
        return taskManager.filteredTasks(in: category)
    }
}

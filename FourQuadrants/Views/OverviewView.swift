import SwiftUI

struct OverviewView: View {
    let title: String
    let color: Color
    let category: TaskCategory
    @ObservedObject var taskManager: TaskManager
    var onZoom: ((TaskCategory) -> Void)? = nil
    @State private var isTargeted: Bool = false

    var body: some View {
        ZStack {
            // 背景使用老版本的低不透明度设计，确保清爽可读
            color.opacity(isTargeted ? 0.4 : 0.15)
                .cornerRadius(18)
            
            VStack(spacing: 0) {
                // Header - 仿照初始版本的黑字+简单布局
                HStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary) // 恢复黑字/深色字
                    
                    Spacer()
                    
                    Button {
                        onZoom?(category)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                Divider()
                    .background(color.opacity(0.3))
                
                // Task List
                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            if filteredTasks.isEmpty {
                                EmptyStateView()
                            } else {
                                ForEach(filteredTasks) { task in
                                    TaskRow(task: task) {
                                        taskManager.toggleTask(task)
                                    }
                                    .onDrag {
                                        NSItemProvider(object: task.id.uuidString as NSString)
                                    }
                                    
                                    Divider()
                                        .background(Color.gray.opacity(0.1))
                                        .padding(.horizontal, 10)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
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

struct EmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 20))
                .foregroundColor(.secondary.opacity(0.3))
            Text("无任务")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
}

import SwiftUI

struct OverviewView: View {
    let title: String
    let color: Color
    let category: TaskCategory
    @ObservedObject var taskManager: TaskManager
    var onZoom: ((TaskCategory) -> Void)? = nil  // **闭包传递**
    @State private var isTargeted: Bool = false  // **拖拽视觉反馈**

    var body: some View {
        ZStack {
            color.opacity(isTargeted ? 0.5 : 0.2) // 拖拽时颜色加深
                .cornerRadius(18)
            VStack {
                HStack {
                    Text(title)
                        .font(.title3)
                        .padding(.leading, 10)
                    Spacer()
                    Button {
                        onZoom?(category)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .padding(8)
                            .bold()
                            .background(Color.gray.opacity(0.45))
                            .foregroundColor(.white.opacity(0.9))
                            .cornerRadius(12)
                    }
                }
                .padding(10)
                Divider()
                GeometryReader { geometry in
                    ScrollView {
                        ForEach(filteredTasks) { task in
                            HStack {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.isCompleted ? .green : .gray)
                                    .padding(5)
                                Text(task.title)
                                    .padding(5)
                                Spacer()
                                if task.isTop {
                                    Image(systemName: "chevron.up.2")
                                        .foregroundColor(.blue)
                                        .padding(.trailing, 16)
                                }
                            }
                            .onTapGesture {
                                taskManager.toggleTask(task)
                            }
                            .padding(.horizontal, 8)
                            .onDrag {
                                NSItemProvider(object: task.id.uuidString as NSString) // **拖拽 ID**
                            }
                            Divider()
                                .background(Color.gray.opacity(0.2))
                                .padding(.leading, 20)
                                .padding(.trailing, 20)
                                .transition(.opacity)
                        }
                    }
                    .frame(height: geometry.size.height)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: ["public.text"], isTargeted: $isTargeted, perform: { providers -> Bool in
            if let provider = providers.first {
                provider.loadObject(ofClass: NSString.self) { (nsString, error) in
                    if let idString = nsString as? String,
                       let uuid = UUID(uuidString: idString),
                       let draggedTask = taskManager.tasks.first(where: { $0.id == uuid }) {
                        DispatchQueue.main.async {
                            taskManager.dragTaskChangeCategory(task: draggedTask, targetCategory: self.category)
                        }
                    }
                }
                return true
            }
            return false
        })
    }
    
    var filteredTasks: [Task] {
        return taskManager.filteredTasks(in: category)
    }
}

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct OverviewView: View {
    let title: String
    let color: Color
    let category: TaskCategory
    @ObservedObject var taskManager: TaskManager
    var onZoom: ((TaskCategory) -> Void)? = nil
    @State private var isTargeted: Bool = false
    @State private var selectedTaskForEditing: QuadrantTask? = nil
    @State private var showingEditTaskView: Bool = false


    var body: some View {
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
                                TaskRow(task: task, onToggle: {
                                    taskManager.toggleTask(task)
                                }, onEdit: {
                                    selectedTaskForEditing = task
                                    showingEditTaskView = true
                                }, onDelete: {
                                    taskManager.removeTask(by: task.id)
                                })
                                // iOS 16+ 现代拖拽 API（使用 TaskTransferItem 包装）
                                .draggable(TaskTransferItem(task: task)) {
                                    // 自定义拖拽预览
                                    TaskDragPreview(task: task, color: color)
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
        .glassEffect(in: .rect(cornerRadius: 18))
        .overlay(
            // 保持拖拽高亮效果
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(isTargeted ? 0.5 : 0), lineWidth: 2)
        )
        // iOS 16+ 现代放置目标 API（接收 TaskTransferItem）
        .dropDestination(for: TaskTransferItem.self) { droppedItems, location in
            for item in droppedItems {
                // 通过 ID 查找实际任务对象
                if let actualTask = taskManager.tasks.first(where: { $0.id == item.taskId }) {
                    taskManager.dragTaskChangeCategory(task: actualTask, targetCategory: self.category)
                }
            }
            return !droppedItems.isEmpty
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        // 长按预览：显示象限的任务列表
        .contextMenu {
            // 空菜单，仅用于显示预览
        } preview: {
            QuadrantPreviewView(category: category, tasks: filteredTasks)
        }
        .sheet(item: $selectedTaskForEditing) { task in
            TaskFormView(taskManager: taskManager, existingTask: task)
        }
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
            Text("no_tasks")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
}

// MARK: - 自定义拖拽预览
struct TaskDragPreview: View {
    let task: QuadrantTask
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(task.title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    let container = try! ModelContainer(
        for: QuadrantTask.self, DailyTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return OverviewView(
        title: "重要且紧急",
        color: .red,
        category: .importantAndUrgent,
        taskManager: TaskManager(modelContext: container.mainContext)
    )
    .frame(height: 300)
    .padding()
    .modelContainer(container)
}

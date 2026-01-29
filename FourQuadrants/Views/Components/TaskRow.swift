import SwiftUI

struct TaskRow: View {
    let task: QuadrantTask
    var onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // 左侧状态图标 - 保持经典圆圈
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(task.isCompleted ? .green : .gray.opacity(0.4))
            
            // 中间标题和日期
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary.opacity(0.5))
                    // 逻辑：有日期胶囊时显示1行节省空间，没日期时显示2行增加信息量
                    .lineLimit(task.targetDate == nil ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let targetDate = task.targetDate {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8, weight: .bold))
                        Text(formattedDate(targetDate))
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(task.isOverdue ? Color.red.opacity(0.12) : Color.blue.opacity(0.1))
                    )
                    .foregroundColor(task.isOverdue ? .red : .blue)
                }
            }
            .padding(.vertical, 4)
            
            Spacer()
            
            // 右侧置顶图标 - 保持右侧排列
            if task.isTop {
                Image(systemName: "chevron.up.2")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue.opacity(0.7))
                    .padding(.trailing, 12)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onToggle()
            }
        }
        // 长按预览：显示任务的所有参数信息
        .contextMenu {
            // 空菜单，仅用于显示预览
        } preview: {
            TaskPreviewView(task: task)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

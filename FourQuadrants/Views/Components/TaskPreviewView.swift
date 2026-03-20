import SwiftUI

/// 长按 Task 时显示的预览小窗口，展示任务的所有参数信息
struct TaskPreviewView: View {
    let task: QuadrantTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题区域
            HStack(spacing: 12) {
                // 状态图标
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        .lineLimit(3)
                    
                    // 象限分类标签
                    Text(task.category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(task.category.themeColor.opacity(0.15))
                        .foregroundColor(task.category.themeColor)
                        .clipShape(Capsule())
                }
            }
            
            Divider()
            
            // 参数列表
            VStack(spacing: 12) {
                // 重要程度
                previewRow(
                    icon: "flag.fill",
                    title: String(localized: "preview_importance"),
                    value: importanceText,
                    color: importanceColor
                )
                
                // 原始重要性（仅当与当前不同时显示）
                if let original = task.originalImportance,
                   original != task.importance {
                    previewRow(
                        icon: "flag",
                        title: String(localized: "preview_original_importance"),
                        value: originalImportanceText(original),
                        color: .purple
                    )
                }
                
                // 紧急状态
                previewRow(
                    icon: "bolt.fill",
                    title: String(localized: "preview_urgent_status"),
                    value: task.isUrgent ? String(localized: "preview_urgent") : String(localized: "preview_not_urgent"),
                    color: task.isUrgent ? .orange : .gray
                )
                
                // 截止日期（不再附带"已逾期"badge）
                if let targetDate = task.targetDate {
                    previewRow(
                        icon: "calendar",
                        title: String(localized: "preview_due_date"),
                        value: formattedFullDate(targetDate),
                        color: task.isOverdue ? .red : .blue
                    )
                }
                
                // 逾期状态（独立一行）
                if task.isOverdue {
                    previewRow(
                        icon: "exclamationmark.triangle.fill",
                        title: String(localized: "preview_overdue_status"),
                        value: String(localized: "preview_overdue"),
                        color: .red
                    )
                }
                
                // 置顶状态
                if task.isTop {
                    previewRow(
                        icon: "pin.fill",
                        title: String(localized: "preview_pinned"),
                        value: String(localized: "preview_pinned_yes"),
                        color: .blue
                    )
                }
                
                // 紧急阈值（显示实际生效的 urgentThresholdDays）
                if let threshold = task.urgentThresholdDays {
                    previewRow(
                        icon: "timer",
                        title: String(localized: "preview_threshold"),
                        value: String(format: String(localized: "preview_threshold_days"), threshold),
                        color: .orange
                    )
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 辅助视图
    
    private func previewRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - 计算属性
    
    private var importanceText: String {
        switch task.importance {
        case .high: return String(localized: "high")
        case .normal: return String(localized: "normal")
        case .low: return String(localized: "low")
        }
    }
    
    private var importanceColor: Color {
        switch task.importance {
        case .high: return .red
        case .normal: return .blue
        case .low: return .gray
        }
    }
    
    private func originalImportanceText(_ level: ImportanceLevel) -> String {
        switch level {
        case .high: return String(localized: "high")
        case .normal: return String(localized: "normal")
        case .low: return String(localized: "low")
        }
    }
    
    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 象限窗格长按预览视图
/// 长按象限窗格时显示的预览，类似 TaskListView 的任务列表
struct QuadrantPreviewView: View {
    let category: TaskCategory
    let tasks: [QuadrantTask]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(category.themeColor)
                    .frame(width: 12, height: 12)
                
                Text(category.displayName)
                    .font(.headline.bold())
                
                Spacer()
                
                Text(String(format: String(localized: "preview_task_count"), tasks.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(category.themeColor.opacity(0.1))
            
            Divider()
            
            // 任务列表
            if tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("preview_no_tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(tasks.prefix(10)) { task in
                            previewTaskRow(task)
                            
                            if task.id != tasks.prefix(10).last?.id {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                        
                        if tasks.count > 10 {
                            HStack {
                                Spacer()
                                Text(String(format: String(localized: "preview_more_tasks"), tasks.count - 10))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: 400)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func previewTaskRow(_ task: QuadrantTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(task.isCompleted ? .green : .gray.opacity(0.4))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .strikethrough(task.isCompleted)
                
                if let targetDate = task.targetDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(formattedDate(targetDate))
                            .font(.caption2)
                    }
                    .foregroundColor(task.isOverdue ? .red : .secondary)
                }
            }
            
            Spacer()
            
            if task.isTop {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

#Preview("Task Preview") {
    TaskPreviewView(task: QuadrantTask(
        title: "完成项目文档",
        date: Date(),
        targetDate: Date().addingTimeInterval(86400 * 3),
        importance: .high,
        isUrgent: true,
        isTop: true
    ))
}

#Preview("Quadrant Preview") {
    QuadrantPreviewView(
        category: .importantAndUrgent,
        tasks: [
            QuadrantTask(title: "任务1", date: Date(), importance: .high, isUrgent: true),
            QuadrantTask(title: "任务2", date: Date(), targetDate: Date(), importance: .high, isUrgent: true)
        ]
    )
}

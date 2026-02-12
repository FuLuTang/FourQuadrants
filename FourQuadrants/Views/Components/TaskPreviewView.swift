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
                    title: "重要程度",
                    value: importanceText,
                    color: importanceColor
                )
                
                // 原始重要性（仅当与当前不同时显示）
                if let original = task.originalImportance,
                   original != task.importance {
                    previewRow(
                        icon: "flag",
                        title: "原始重要性",
                        value: originalImportanceText(original),
                        color: .purple
                    )
                }
                
                // 紧急状态
                previewRow(
                    icon: "bolt.fill",
                    title: "紧急状态",
                    value: task.isUrgent ? "紧急" : "不紧急",
                    color: task.isUrgent ? .orange : .gray
                )
                
                // 截止日期
                if let targetDate = task.targetDate {
                    previewRow(
                        icon: "calendar",
                        title: "截止日期",
                        value: formattedFullDate(targetDate),
                        color: task.isOverdue ? .red : .blue,
                        badge: task.isOverdue ? "已逾期" : nil
                    )
                }
                
                // 创建日期
                previewRow(
                    icon: "clock",
                    title: "创建时间",
                    value: formattedFullDate(task.date),
                    color: .secondary
                )
                
                // 最后修改
                previewRow(
                    icon: "pencil.circle",
                    title: "最后修改",
                    value: formattedFullDate(task.dateLatestModified),
                    color: .secondary
                )
                
                // 置顶状态
                if task.isTop {
                    previewRow(
                        icon: "pin.fill",
                        title: "置顶",
                        value: "已置顶",
                        color: .blue
                    )
                }
                
                // 紧急阈值信息
                if let original = task.originalUrgentThresholdDays {
                    previewRow(
                        icon: "timer",
                        title: "原始阈值",
                        value: "剩余 \(original) 天时触发",
                        color: .orange
                    )
                }
                if let threshold = task.urgentThresholdDays,
                   threshold != task.originalUrgentThresholdDays {
                    previewRow(
                        icon: "timer.circle",
                        title: "自动阈值",
                        value: "剩余 \(threshold) 天时触发",
                        color: .yellow
                    )
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 辅助视图
    
    private func previewRow(icon: String, title: String, value: String, color: Color, badge: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                if let badge = badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var importanceText: String {
        switch task.importance {
        case .high: return "高"
        case .normal: return "普通"
        case .low: return "低"
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
        case .high: return "高"
        case .normal: return "普通"
        case .low: return "低"
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
                
                Text("\(tasks.count) 项任务")
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
                    Text("暂无任务")
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
                                Text("还有 \(tasks.count - 10) 项...")
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

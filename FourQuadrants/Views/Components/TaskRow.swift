import SwiftUI

struct TaskRow: View {
    let task: Task
    var onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // MARK: - Liquid Checkbox
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted ? Color.clear : Color.secondary.opacity(0.2),
                            lineWidth: 1.5
                        )
                        .background(
                            Circle()
                                .fill(task.isCompleted ? 
                                      LinearGradient(colors: [AppTheme.Colors.urgentNotImportant, AppTheme.Colors.importantNotUrgent], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [.white.opacity(0.05), .clear], startPoint: .top, endPoint: .bottom))
                        )
                        .frame(width: 28, height: 28)
                        .shadow(color: task.isCompleted ? AppTheme.Colors.importantNotUrgent.opacity(0.5) : .clear, radius: 8, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(task.isCompleted ? 0.5 : 0), lineWidth: 1)
                                .scaleEffect(task.isCompleted ? 1.0 : 0.001)
                        )
                    
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.push(from: .bottom).combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(FloatButtonStyle()) // Use new touch feedback
            
            // MARK: - Task Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    if task.isTop {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .padding(4)
                            .background(Circle().fill(AppTheme.Colors.urgentImportant.opacity(0.2)))
                            .foregroundStyle(AppTheme.Colors.urgentImportant)
                    }
                    
                    Text(task.title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(task.isCompleted ? .regular : .semibold)
                        .strikethrough(task.isCompleted, color: .secondary.opacity(0.5))
                        .foregroundColor(task.isCompleted ? .secondary : AppTheme.Colors.textPrimary)
                        // Fluid transition for text style
                        .animation(.smooth, value: task.isCompleted)
                }
                
                if let targetDate = task.targetDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(formattedDate(targetDate))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(task.isOverdue ? Color.red.opacity(0.15) : Material.ultraThin)
                    )
                    .foregroundColor(task.isOverdue ? .red : .secondary)
                }
            }
            
            Spacer()
            
            // MARK: - Priority Indicator (Ambient Light)
            if task.importance == .high && !task.isCompleted {
                Circle()
                    .fill(AppTheme.Colors.urgentImportant)
                    .frame(width: 6, height: 6)
                    .shadow(color: AppTheme.Colors.urgentImportant.opacity(0.8), radius: 6, x: 0, y: 0)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.urgentImportant.opacity(0.3), lineWidth: 4)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                    )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.01)) // Invisible touch target for drag/swipe
        )
        .contentShape(Rectangle()) 
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // More compact
        return formatter.string(from: date)
    }
}

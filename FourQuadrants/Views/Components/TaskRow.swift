import SwiftUI

struct TaskRow: View {
    let task: QuadrantTask
    var onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    onToggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted ? Color.clear : Color.secondary.opacity(0.3),
                            lineWidth: 2
                        )
                        .background(
                            Circle()
                                .fill(task.isCompleted ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom))
                        )
                        .frame(width: 24, height: 24)
                        .shadow(color: task.isCompleted ? .green.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
                    
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(.plain)

            // MARK: - Task Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if task.isTop {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                    }
                    Text(task.title)
                        .font(.system(.subheadline, design: .rounded)) // Reduce to subheadline
                        .fontWeight(task.isCompleted ? .regular : .medium)
                        .strikethrough(task.isCompleted, color: .secondary.opacity(0.5))
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .lineLimit(1) // Avoid multiline sprawl
                }
                
                if let targetDate = task.targetDate {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8))
                        Text(formattedDate(targetDate))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(task.isOverdue ? Color.red.opacity(0.1) : Color.blue.opacity(0.05))
                    )
                    .foregroundColor(task.isOverdue ? .red : .secondary)
                }
            }
            
            Spacer()
            
            // 重要性小标记 (Glowing Dot)
            if task.importance == .high && !task.isCompleted {
                Circle()
                    .fill(AppTheme.Colors.urgentImportant)
                    .frame(width: 6, height: 6)
                    .shadow(color: AppTheme.Colors.urgentImportant.opacity(0.6), radius: 3, x: 0, y: 0)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle()) // Ensure tap area covers the whole row
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

import SwiftUI
import SwiftData

struct DailyTaskBlock: View {
    @Bindable var task: DailyTask
    let hourHeight: CGFloat
    @Environment(\.modelContext) private var modelContext
    
    // State Machine
    @State private var editMode: TaskBlockState = .normal
    @State private var showEditSheet = false
    
    // Gesture Temporary State
    @State private var initialStartTime: Date?
    @State private var initialDuration: TimeInterval?
    
    // Helpers
    private let interaction = TaskInteractionManager.shared
    
    var body: some View {
        let duration = task.duration
        let height = (CGFloat(duration) / 3600.0) * hourHeight
        
        ZStack(alignment: .topLeading) {
            // --- 任务卡片主体 ---
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: task.colorHex ?? "#5E81F4"))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(task.startTime.formatted(date: .omitted, time: .shortened)) - \(task.startTime.addingTimeInterval(task.duration).formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(6)
                }
                // 编辑态视觉强化：白色描边 + 提升阴影
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: editMode == .editing ? 2 : 0)
                )
                .shadow(
                    color: editMode == .editing ? .black.opacity(0.25) : .black.opacity(0.1),
                    radius: editMode == .editing ? 8 : 2,
                    y: editMode == .editing ? 4 : 1
                )
        }
        .frame(height: max(height, 20))
        // 编辑态：添加调整手柄 (使用 overlay 避免影响布局)
        .overlay(alignment: .topLeading) {
            if editMode == .editing {
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(radius: 1)
                    .offset(x: -4, y: -4) // 块顶靠左小圆
                    .gesture(resizeTopGesture)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if editMode == .editing {
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(radius: 1)
                    .offset(x: 4, y: 4) // 块底靠右小圆
                    .gesture(resizeBottomGesture)
            }
        }
        .contentShape(Rectangle()) // 确保点击区域覆盖整个 Frame
        // --- 交互逻辑 ---
        .onTapGesture {
            if editMode == .normal {
                showEditSheet = true
            } else {
                // 编辑态下点击退出编辑
                withAnimation { editMode = .normal }
            }
        }
        .onLongPressGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                editMode = (editMode == .normal) ? .editing : .normal
            }
        }
        // 只有编辑态可以拖拽主体移动
        .gesture(
            editMode == .editing ? dragBodyGesture : nil
        )
        // Sheet for details
        .sheet(isPresented: $showEditSheet) {
            DailyTaskFormView(task: task, selectedDate: task.scheduledDate)
        }
        // Native Haptics: Trigger on value change
        .sensoryFeedback(.impact(weight: .light), trigger: task.startTime)
        .sensoryFeedback(.impact(weight: .light), trigger: task.duration)
        .sensoryFeedback(.impact(weight: .medium), trigger: editMode) { oldValue, newValue in
            // Only trigger when entering/exiting edit mode
            return oldValue != newValue
        }
    }
    
    // MARK: - Gestures
    
    // 1. Body Drag: Move Time (Snapping)
    var dragBodyGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if initialStartTime == nil { initialStartTime = task.startTime }
                guard let start = initialStartTime else { return }
                
                let deltaHours = Double(value.translation.height / hourHeight)
                let rawDate = start.addingTimeInterval(deltaHours * 3600)
                let snappedDate = interaction.snapTime(rawDate, intervalMinutes: 15)
                
                if snappedDate != task.startTime {
                    task.startTime = snappedDate
                }
            }
            .onEnded { _ in
                initialStartTime = nil
                LiveActivityManager.shared.checkTask(context: modelContext)
            }
    }
    
    // 2. Bottom Handle: Resize Duration (Snapping)
    var resizeBottomGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if initialDuration == nil { initialDuration = task.duration }
                guard let startDuration = initialDuration else { return }
                
                let deltaHours = Double(value.translation.height / hourHeight)
                let rawDuration = startDuration + (deltaHours * 3600)
                let snappedDuration = interaction.snapDuration(rawDuration, intervalMinutes: 15)
                
                if snappedDuration != task.duration {
                    task.duration = snappedDuration
                }
            }
            .onEnded { _ in
                initialDuration = nil
                LiveActivityManager.shared.checkTask(context: modelContext)
            }
    }
    
    // 3. Top Handle: Resize Start Time (Keep End Time, change moves start)
    var resizeTopGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if initialStartTime == nil {
                    initialStartTime = task.startTime
                    initialDuration = task.duration
                }
                guard let start = initialStartTime, let duration = initialDuration else { return }
                
                let deltaHours = Double(value.translation.height / hourHeight)
                let rawNewStart = start.addingTimeInterval(deltaHours * 3600)
                let snappedNewStart = interaction.snapTime(rawNewStart, intervalMinutes: 15)
                
                // Calculate new duration to keep end time constant
                let originalEnd = start.addingTimeInterval(duration)
                let newDuration = originalEnd.timeIntervalSince(snappedNewStart)
                
                if newDuration >= 900 && snappedNewStart != task.startTime {
                    task.startTime = snappedNewStart
                    task.duration = newDuration
                }
            }
            .onEnded { _ in
                initialStartTime = nil
                initialDuration = nil
                LiveActivityManager.shared.checkTask(context: modelContext)
            }
    }
}

// MARK: - Interaction Helpers

enum TaskBlockState {
    case normal
    case editing
}

struct TaskInteractionManager {
    static let shared = TaskInteractionManager()

    func snapTime(_ date: Date, intervalMinutes: Int = 15) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let hour = calendar.component(.hour, from: date)
        let totalMinutes = Double(hour * 60 + minute)
        // Round to nearest interval
        let snappedMinutes = round(totalMinutes / Double(intervalMinutes)) * Double(intervalMinutes)
        
        return calendar.date(bySettingHour: Int(snappedMinutes) / 60, minute: Int(snappedMinutes) % 60, second: 0, of: date) ?? date
    }
    
    func snapDuration(_ duration: TimeInterval, intervalMinutes: Int = 15) -> TimeInterval {
        let intervalSeconds = Double(intervalMinutes) * 60.0
        return max(intervalSeconds, round(duration / intervalSeconds) * intervalSeconds)
    }
}

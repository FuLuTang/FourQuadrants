import SwiftUI
import SwiftData

struct DailyTaskBlock: View {
    @Bindable var task: DailyTask
    let hourHeight: CGFloat
    
    @Environment(\.modelContext) private var modelContext
    
    @Binding var editingTaskId: PersistentIdentifier?
    
    // State Machine
    private var editMode: TaskBlockState {
        editingTaskId == task.id ? .editing : .normal
    }
    @State private var showEditSheet = false
    
    // Gesture State
    @GestureState private var isDraggingBody = false
    @State private var initialStartTime: Date?
    @State private var initialDuration: TimeInterval?
    
    // Internal
    private let interaction = TaskInteractionManager.shared
    
    var body: some View {
        let duration = task.duration
        let height = (CGFloat(duration) / 3600.0) * hourHeight
        
        ZStack(alignment: .topLeading) {
            // --- Task Card ---
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: task.colorHex ?? "#5E81F4").opacity(editMode == .editing ? 0.9 : 0.8))
                .glassEffect(
                    .clear.tint(Color(hex: task.colorHex ?? "#5E81F4").opacity(0.1)).interactive(),
                    in: .rect(cornerRadius: 12)
                )
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
                    .padding(8)
                }
                // Edit Mode Visuals
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.8), lineWidth: editMode == .editing ? 2 : 0)
                )
                .shadow(
                    color: editMode == .editing ? .black.opacity(0.3) : .black.opacity(0.1),
                    radius: editMode == .editing ? 10 : 4,
                    y: editMode == .editing ? 5 : 2
                )
        }
        .frame(height: max(height, 30))
        // Resize Handles (Edit Mode Only)
        .overlay(alignment: .top) {
            if editMode == .editing {
                // Resize Top Zone (Invisible but touchable)
                Color.clear
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .overlay(
                        Capsule()
                            .fill(.white.opacity(0.5))
                            .frame(width: 24, height: 4)
                    )
                    .offset(y: -10)
                    .gesture(resizeTopGesture)
            }
        }
        .overlay(alignment: .bottom) {
            if editMode == .editing {
                // Resize Bottom Zone
                Color.clear
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .overlay(
                        Capsule()
                            .fill(.white.opacity(0.5))
                            .frame(width: 24, height: 4)
                    )
                    .offset(y: 10)
                    .gesture(resizeBottomGesture)
            }
        }
        .contentShape(Rectangle())
        // --- Interactions ---
        .onTapGesture {
            if editMode == .normal {
                showEditSheet = true
            } else {
                // Tap self in edit mode -> Do nothing
            }
        }
        // Sequenced Gesture: Long Press -> Drag (Move) OR Long Press -> Release (Edit)
        .gesture(
            editMode == .normal ? combinedGestures : nil
        )
        // Edit Mode: Drag Body to Move
        .gesture(
            editMode == .editing ? dragBodyGesture(isEditMode: true) : nil
        )
        .sheet(isPresented: $showEditSheet) {
            DailyTaskFormView(task: task, selectedDate: task.scheduledDate)
        }
        // Native Haptics: Trigger on value change
        .sensoryFeedback(.impact(weight: .light), trigger: task.startTime)
        .sensoryFeedback(.impact(weight: .light), trigger: task.duration)
        // Haptic on Enter Edit Mode
        .sensoryFeedback(.impact(weight: .medium), trigger: editMode) { old, new in
            return old != new && new == .editing
        }
        .scaleEffect(isDraggingBody ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingBody)
    }
    
    // MARK: - Combined Gesture (Normal Mode)
    
    var combinedGestures: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($isDraggingBody) { value, state, _ in
                switch value {
                case .second(true, _):
                    state = true
                default:
                    state = false
                }
            }
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    // Entering "Picked Up" state
                    // If drag is nil, it's just the long press phase transitioning
                    guard let drag = drag else { return }
                    
                    // Logic: Move Task
                    handleMove(drag: drag)
                    
                default: break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag):
                    if let drag = drag, abs(drag.translation.height) > 10 {
                        // Was dragging -> Drop
                        finalizeMove()
                    } else {
                        // Was stationary -> Enter Edit Mode
                        withAnimation { editingTaskId = task.id }
                    }
                default: break
                }
            }
    }
    
    // MARK: - Helper Gestures
    
    func dragBodyGesture(isEditMode: Bool) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                handleMove(drag: value)
            }
            .onEnded { _ in
                finalizeMove()
            }
    }
    
    var resizeBottomGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
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
                checkLiveActivity()
            }
    }
    
    var resizeTopGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                if initialStartTime == nil {
                    initialStartTime = task.startTime
                    initialDuration = task.duration
                }
                guard let start = initialStartTime, let duration = initialDuration else { return }
                
                let deltaHours = Double(value.translation.height / hourHeight)
                let rawNewStart = start.addingTimeInterval(deltaHours * 3600)
                let snappedNewStart = interaction.snapTime(rawNewStart, intervalMinutes: 15)
                
                // Calculate new duration
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
                checkLiveActivity()
            }
    }
    
    // MARK: - Logic
    
    private func handleMove(drag: DragGesture.Value) {
        if initialStartTime == nil { initialStartTime = task.startTime }
        guard let start = initialStartTime else { return }
        
        let deltaHours = Double(drag.translation.height / hourHeight)
        let rawDate = start.addingTimeInterval(deltaHours * 3600)
        let snappedDate = interaction.snapTime(rawDate, intervalMinutes: 15)
        
        if snappedDate != task.startTime {
            task.startTime = snappedDate
        }
    }
    
    private func finalizeMove() {
        initialStartTime = nil
        checkLiveActivity()
    }
    
    private func checkLiveActivity() {
        LiveActivityManager.shared.checkTask(context: modelContext)
    }
}

// MARK: - Helpers

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
        let snappedMinutes = round(totalMinutes / Double(intervalMinutes)) * Double(intervalMinutes)
        
        return calendar.date(bySettingHour: Int(snappedMinutes) / 60, minute: Int(snappedMinutes) % 60, second: 0, of: date) ?? date
    }
    
    func snapDuration(_ duration: TimeInterval, intervalMinutes: Int = 15) -> TimeInterval {
        let intervalSeconds = Double(intervalMinutes) * 60.0
        return max(intervalSeconds, round(duration / intervalSeconds) * intervalSeconds)
    }
}

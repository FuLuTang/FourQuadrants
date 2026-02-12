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
    @State private var showContextMenu = false // Custom Menu State
    
    // Gesture State
    @GestureState private var isDraggingBody = false
    @State private var initialStartTime: Date?
    @State private var initialDuration: TimeInterval?
    
    // Internal
    private let interaction = TaskInteractionManager.shared
    
    var body: some View {
        let height = (CGFloat(task.duration) / 3600.0) * hourHeight
        
        ZStack(alignment: .topLeading) {
            taskCard
                .zIndex(1) // Base layer
            
            // Custom Context Menu Overlay
            if showContextMenu && !isDraggingBody {
                contextMenu
                    .zIndex(100)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .padding(.bottom, 10) // Spacing from card
                    .alignmentGuide(.bottom) { _ in 0 } // Align to bottom of container?? No.
                    // We want it positioned relevant to the card. 
                    // Let's use overlay on the card or ZStack.
                    // ZStack alignment is topLeading.
                    // We want the menu to appear probably centered horizontally on the card, and above or below.
                    // Let's position it "Above" the card.
            }
        }
        .frame(height: max(height, 30))
        .overlay(alignment: .top) { 
            if showContextMenu && !isDraggingBody {
                contextMenu
                    .offset(y: -45) // Shift up above the card
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) { topResizeHandle }
        .overlay(alignment: .bottom) { bottomResizeHandle }
        .contentShape(Rectangle())
        // --- Interactions ---
        .onTapGesture {
            if showContextMenu {
                withAnimation { showContextMenu = false }
            } else if editMode == .normal {
                showEditSheet = true
            }
        }
        // Sequenced Gesture: Long Press -> Drag (Move) OR Long Press -> Context Menu
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
        // Native Haptics
        .sensoryFeedback(.impact(weight: .light), trigger: task.startTime)
        .sensoryFeedback(.impact(weight: .light), trigger: task.duration)
        .sensoryFeedback(.impact(weight: .medium), trigger: showContextMenu) { old, new in return new }
        .scaleEffect(isDraggingBody ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingBody)
        .zIndex(showContextMenu || isDraggingBody ? 10 : 1) // Bring to front
    }
    
    // MARK: - Subviews
    
    private var contextMenu: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation {
                    showContextMenu = false
                    showEditSheet = true
                }
            } label: {
                Label(String(localized: "edit"), systemImage: "pencil")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.primary)

            Divider()
                .frame(height: 20)
            
            Button {
                withAnimation {
                    modelContext.delete(task)
                    checkLiveActivity()
                }
            } label: {
                Label(String(localized: "delete"), systemImage: "trash")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.red)
        }
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
    
    private var taskCard: some View {
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
                        
                    // Notes Display
                    if let notes = task.notes, !notes.isEmpty, (CGFloat(task.duration) / 3600.0) * hourHeight > 50 {
                        Text(notes)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
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
    
    @ViewBuilder
    private var topResizeHandle: some View {
        if editMode == .editing {
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
    
    @ViewBuilder
    private var bottomResizeHandle: some View {
        if editMode == .editing {
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
    
    // MARK: - Combined Gesture (Normal Mode)
    
    var combinedGestures: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($isDraggingBody) { value, state, _ in
                switch value {
                case .second(true, let drag):
                    if let drag = drag, abs(drag.translation.height) > 5 {
                         state = true
                    }
                default:
                    state = false
                }
            }
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    if let drag = drag, abs(drag.translation.height) > 5 {
                        if showContextMenu { withAnimation { showContextMenu = false } }
                        handleMove(drag: drag)
                    }
                default: break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag):
                    if let drag = drag, abs(drag.translation.height) > 10 {
                        finalizeMove()
                    } else {
                        // Stationary Long Press -> Toggle Menu
                        withAnimation { showContextMenu.toggle() }
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

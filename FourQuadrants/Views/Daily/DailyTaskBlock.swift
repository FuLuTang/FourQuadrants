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
    
    // Gesture State - Now using @State for UIKit-driven updates
    @State private var isDraggingBody = false
    @State private var initialStartTime: Date?
    @State private var initialDuration: TimeInterval?
    
    // Internal
    private let interaction = TaskInteractionManager.shared
    
    var body: some View {
        let height = (CGFloat(task.duration) / 3600.0) * hourHeight
        
        ZStack(alignment: .topLeading) {
            taskCard
                .zIndex(1)
            
            // --- UIKit Interaction Overlay (The Core Optimization) ---
            TaskInteractionOverlay(
                isEditing: Binding(
                    get: { editingTaskId == task.id },
                    set: { newValue in
                        withAnimation {
                            editingTaskId = newValue ? task.id : nil
                        }
                    }
                ),
                onMove: { deltaY in
                    handleMove(deltaY: deltaY)
                },
                onResizeTop: { deltaY in
                    handleResizeTop(deltaY: deltaY)
                },
                onResizeBottom: { deltaY in
                    handleResizeBottom(deltaY: deltaY)
                },
                onEnd: {
                    finalizeInteraction()
                },
                onSelect: {
                    if showContextMenu {
                        withAnimation { showContextMenu = false }
                    } else if editMode == .normal {
                        showEditSheet = true
                    }
                }
            )
            .zIndex(5)
        }
        .frame(height: max(height, 30))
        .overlay(alignment: .top) { 
            if showContextMenu && !isDraggingBody {
                contextMenu
                    .offset(y: -45)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) { topResizeHandle }
        .overlay(alignment: .bottom) { bottomResizeHandle }
        .contentShape(Rectangle())
        .sheet(isPresented: $showEditSheet) {
            DailyTaskFormView(task: task, selectedDate: task.scheduledDate)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: task.startTime)
        .sensoryFeedback(.impact(weight: .light), trigger: task.duration)
        .sensoryFeedback(.impact(weight: .medium), trigger: showContextMenu) { _, new in return new }
        .scaleEffect(isDraggingBody ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingBody)
        .zIndex(showContextMenu || isDraggingBody ? 10 : 1)
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
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: 24, height: 4)
                .padding(.top, 4)
                .allowsHitTesting(false) // Let UIKit overlay handle the hits
        }
    }
    
    @ViewBuilder
    private var bottomResizeHandle: some View {
        if editMode == .editing {
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: 24, height: 4)
                .padding(.bottom, 4)
                .allowsHitTesting(false) // Let UIKit overlay handle the hits
        }
    }
    
    // MARK: - Logic Refined for UIKit
    
    private func handleMove(deltaY: CGFloat) {
        if initialStartTime == nil { 
            initialStartTime = task.startTime 
            withAnimation { isDraggingBody = true }
        }
        guard let start = initialStartTime else { return }
        
        let deltaHours = Double(deltaY / hourHeight)
        let rawDate = start.addingTimeInterval(deltaHours * 3600)
        let snappedDate = interaction.snapTime(rawDate, intervalMinutes: 15)
        
        if snappedDate != task.startTime {
            task.startTime = snappedDate
        }
    }
    
    private func handleResizeBottom(deltaY: CGFloat) {
        if initialDuration == nil { 
            initialDuration = task.duration 
            withAnimation { isDraggingBody = true }
        }
        guard let startDuration = initialDuration else { return }
        
        let deltaHours = Double(deltaY / hourHeight)
        let rawDuration = startDuration + (deltaHours * 3600)
        let snappedDuration = interaction.snapDuration(rawDuration, intervalMinutes: 15)
        
        if snappedDuration != task.duration {
            task.duration = snappedDuration
        }
    }
    
    private func handleResizeTop(deltaY: CGFloat) {
        if initialStartTime == nil {
            initialStartTime = task.startTime
            initialDuration = task.duration
            withAnimation { isDraggingBody = true }
        }
        guard let start = initialStartTime, let duration = initialDuration else { return }
        
        let deltaHours = Double(deltaY / hourHeight)
        let rawNewStart = start.addingTimeInterval(deltaHours * 3600)
        let snappedNewStart = interaction.snapTime(rawNewStart, intervalMinutes: 15)
        
        let originalEnd = start.addingTimeInterval(duration)
        let newDuration = originalEnd.timeIntervalSince(snappedNewStart)
        
        if newDuration >= 900 && snappedNewStart != task.startTime {
            task.startTime = snappedNewStart
            task.duration = newDuration
        }
    }
    
    private func finalizeInteraction() {
        withAnimation { isDraggingBody = false }
        initialStartTime = nil
        initialDuration = nil
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

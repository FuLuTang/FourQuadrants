import SwiftUI
import SwiftData

struct DailyTaskBlock: View {
    @Bindable var task: DailyTask
    let hourHeight: CGFloat
    /// Optional visible interval used when a task is clipped at midnight.
    let displayStartAt: Date?
    let displayDuration: TimeInterval?

    init(
        task: DailyTask,
        hourHeight: CGFloat,
        editingTaskId: Binding<PersistentIdentifier?>,
        displayStartAt: Date? = nil,
        displayDuration: TimeInterval? = nil
    ) {
        self._task = Bindable(task)
        self.hourHeight = hourHeight
        self._editingTaskId = editingTaskId
        self.displayStartAt = displayStartAt
        self.displayDuration = displayDuration
    }
    
    @Environment(TaskStore.self) private var taskStore
    
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
        let height = (CGFloat(displayDuration ?? task.duration) / 3600.0) * hourHeight
        
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
                    commitInteraction()
                },
                onCancelled: {
                    cancelInteraction()
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
        .overlay(alignment: .topTrailing) {
            DailyCompletionButton(isCompleted: task.isCompleted) {
                _ = taskStore.toggleDailyTask(task)
            }
                .zIndex(10)
        }
        .overlay(alignment: .top) { 
            if showContextMenu && !isDraggingBody {
                DailyTaskContextMenu(
                    onEdit: {
                        withAnimation {
                            showContextMenu = false
                            showEditSheet = true
                        }
                    },
                    onDelete: {
                        withAnimation {
                            _ = taskStore.removeDailyTask(task)
                        }
                    }
                )
                    .offset(y: -45)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) { topResizeHandle }
        .overlay(alignment: .bottom) { bottomResizeHandle }
        .contentShape(Rectangle())
        .sheet(isPresented: $showEditSheet) {
            DailyTaskFormView(task: task, selectedDate: task.startAt)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: task.startAt)
        .sensoryFeedback(.impact(weight: .light), trigger: task.duration)
        .sensoryFeedback(.impact(weight: .medium), trigger: showContextMenu) { _, new in return new }
        .scaleEffect(isDraggingBody ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingBody)
        .zIndex(showContextMenu || isDraggingBody ? 10 : 1)
    }
    
    // MARK: - Subviews
    private var taskCard: some View {
        DailyTaskCard(
            title: task.title,
            colorHex: task.colorHex,
            isCompleted: task.isCompleted,
            isEditing: editMode == .editing,
            visibleStartAt: displayStartAt ?? task.startAt,
            visibleDuration: displayDuration ?? task.duration,
            notes: task.notes,
            hourHeight: hourHeight
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
            initialStartTime = task.startAt
            withAnimation { isDraggingBody = true }
        }
        guard let start = initialStartTime else { return }
        
        let deltaHours = Double(deltaY / hourHeight)
        let rawDate = start.addingTimeInterval(deltaHours * 3600)
        let snappedDate = interaction.snapTime(rawDate, intervalMinutes: 15)
        
        if snappedDate != task.startAt {
            taskStore.previewDailyTaskLayout(task, startAt: snappedDate, duration: task.duration)
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
            taskStore.previewDailyTaskLayout(task, startAt: task.startAt, duration: snappedDuration)
        }
    }
    
    private func handleResizeTop(deltaY: CGFloat) {
        if initialStartTime == nil {
            initialStartTime = task.startAt
            initialDuration = task.duration
            withAnimation { isDraggingBody = true }
        }
        guard let start = initialStartTime, let duration = initialDuration else { return }
        
        let deltaHours = Double(deltaY / hourHeight)
        let rawNewStart = start.addingTimeInterval(deltaHours * 3600)
        let snappedNewStart = interaction.snapTime(rawNewStart, intervalMinutes: 15)
        
        let originalEnd = start.addingTimeInterval(duration)
        let newDuration = originalEnd.timeIntervalSince(snappedNewStart)
        
        if newDuration >= 900 && snappedNewStart != task.startAt {
            taskStore.previewDailyTaskLayout(task, startAt: snappedNewStart, duration: newDuration)
        }
    }
    
    private func commitInteraction() {
        if initialStartTime != nil || initialDuration != nil {
            _ = taskStore.commitDailyTaskLayout(task)
        }
        resetInteractionState()
    }

    private func cancelInteraction() {
        if let initialStartTime {
            taskStore.restoreDailyTaskLayout(task, startAt: initialStartTime, duration: initialDuration ?? task.duration)
        } else if let initialDuration {
            taskStore.restoreDailyTaskLayout(task, startAt: task.startAt, duration: initialDuration)
        }
        resetInteractionState()
    }

    private func resetInteractionState() {
        withAnimation { isDraggingBody = false }
        initialStartTime = nil
        initialDuration = nil
    }
}

private struct DailyCompletionButton: View {
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(localized: isCompleted ? "menu_mark_incomplete" : "menu_complete_task")
        )
        .accessibilityHint(String(localized: "daily_toggle_completion_hint"))
    }
}

private struct DailyTaskContextMenu: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onEdit) {
                Label(String(localized: "edit"), systemImage: "pencil")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.primary)

            Divider()
                .frame(height: 20)

            Button(action: onDelete) {
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
}

private struct DailyTaskCard: View {
    let title: String
    let colorHex: String?
    let isCompleted: Bool
    let isEditing: Bool
    let visibleStartAt: Date
    let visibleDuration: TimeInterval
    let notes: String?
    let hourHeight: CGFloat

    var body: some View {
        let color = Color(hex: colorHex ?? "#5E81F4")
        let visibleEndAt = visibleStartAt.addingTimeInterval(visibleDuration)
        let blockHeight = (CGFloat(visibleDuration) / 3600.0) * hourHeight
        let showsTime = blockHeight >= 48
        let showsNotes = blockHeight >= 72
        let compactTime = "\(visibleStartAt.formatted(date: .omitted, time: .shortened))-\(visibleEndAt.formatted(date: .omitted, time: .shortened))"

        return RoundedRectangle(cornerRadius: 12)
            .fill(color.opacity(isCompleted ? 0.45 : (isEditing ? 0.9 : 0.8)))
            .glassEffect(
                .clear.tint(color.opacity(0.1)).interactive(),
                in: .rect(cornerRadius: 12)
            )
            .overlay(alignment: .topLeading) {
                if showsTime {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .strikethrough(isCompleted, color: .white)

                        Text("\(visibleStartAt.formatted(date: .omitted, time: .shortened)) - \(visibleEndAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)

                        if let notes, !notes.isEmpty, showsNotes {
                            Text(notes)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    .padding(8)
                } else {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                            .strikethrough(isCompleted, color: .white)

                        Text(compactTime)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if isCompleted {
                    Label("category_completed", systemImage: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.leading, 8)
                        .padding(.bottom, 6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.8), lineWidth: isEditing ? 2 : 0)
            )
            .shadow(
                color: isEditing ? .black.opacity(0.3) : .black.opacity(0.1),
                radius: isEditing ? 10 : 4,
                y: isEditing ? 5 : 2
            )
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

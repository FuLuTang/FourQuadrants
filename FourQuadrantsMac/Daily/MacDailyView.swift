import SwiftData
import SwiftUI

private struct MacDailyTaskPresentation: Identifiable {
    let id = UUID()
    let task: DailyTask?
    let selectedDate: Date
    let initialStartAt: Date
}

/// Native macOS daily planner. The host supplies the shared SwiftData container
/// and the shared `TaskStore` through the environment.
struct MacDailyView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var selectedTask: DailyTask?
    @State private var taskPresentation: MacDailyTaskPresentation?

    var body: some View {
        VStack(spacing: 0) {
            MacDailyHeader(
                date: selectedDate,
                hasSelection: selectedTask != nil,
                isSelectionCompleted: selectedTask?.isCompleted ?? false,
                onPrevious: { changeDay(by: -1) },
                onNext: { changeDay(by: 1) },
                onToday: { selectToday() },
                onDateChange: {
                    selectedDate = Calendar.current.startOfDay(for: $0)
                    selectedTask = nil
                },
                onNew: { presentNewTask(at: defaultStartTime()) },
                onEdit: presentSelectedTask,
                onToggleCompletion: toggleSelectedTask,
                onDelete: deleteSelectedTask
            )

            Divider()

            MacDailyTimeline(
                date: selectedDate,
                selectedTaskID: selectedTask?.id,
                onSelect: { selectedTask = $0 },
                onEdit: { task in
                    selectedTask = task
                    presentTask(task)
                },
                onDelete: { task in
                    if taskStore.removeDailyTask(task), selectedTask?.id == task.id { selectedTask = nil }
                },
                onNew: presentNewTask
            )
            .id(Calendar.current.startOfDay(for: selectedDate))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        // This view lives in the Workspace split-view detail column; keep its
        // sizing flexible and let the window/container own minimum dimensions.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $taskPresentation) { presentation in
            MacDailyTaskFormView(
                task: presentation.task,
                selectedDate: presentation.selectedDate,
                initialStartAt: presentation.initialStartAt
            ) { savedTask in
                if let savedTask { selectedTask = savedTask }
            }
                .environment(taskStore)
                .frame(minWidth: 520, minHeight: 620)
        }
    }

    private func changeDay(by offset: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        selectedDate = Calendar.current.startOfDay(for: next)
        selectedTask = nil
    }

    private func selectToday() {
        selectedDate = Calendar.current.startOfDay(for: .now)
        selectedTask = nil
    }

    private func presentNewTask(at time: Date) {
        selectedTask = nil
        taskPresentation = MacDailyTaskPresentation(
            task: nil,
            selectedDate: Calendar.current.startOfDay(for: time),
            initialStartAt: time
        )
    }

    private func defaultStartTime() -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        if calendar.isDateInToday(selectedDate) {
            let now = Date()
            let minute = MacDailyTimeMath.snapped(MacDailyTimeMath.minuteOfDay(now) + 60)
            return MacDailyTimeMath.date(on: dayStart, minute: min(minute, MacDailyTimeMath.latestNewTaskMinute))
        }
        return MacDailyTimeMath.date(on: dayStart, minute: MacDailyTimeMath.defaultNewTaskMinute)
    }

    private func presentSelectedTask() {
        guard let selectedTask else { return }
        presentTask(selectedTask)
    }

    private func presentTask(_ task: DailyTask) {
        taskPresentation = MacDailyTaskPresentation(
            task: task,
            selectedDate: Calendar.current.startOfDay(for: task.startAt),
            initialStartAt: task.startAt
        )
    }

    private func toggleSelectedTask() {
        guard let selectedTask else { return }
        // iOS DailyTaskBlock toggles only the DailyTask via this same Store API.
        _ = taskStore.toggleDailyTask(selectedTask)
    }

    private func deleteSelectedTask() {
        guard let selectedTask else { return }
        if taskStore.removeDailyTask(selectedTask) { self.selectedTask = nil }
    }
}

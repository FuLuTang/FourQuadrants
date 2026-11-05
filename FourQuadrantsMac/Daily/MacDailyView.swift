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
    /// 等待确认删除的日程；三个删除入口（头部按钮、Delete 键、时间轴右键）都只设置它。
    @State private var pendingDeleteTask: DailyTask?

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
                onDelete: requestDeleteSelectedTask
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
                onDelete: requestDelete,
                onNew: presentNewTask,
                onDeselect: { selectedTask = nil }
            )
            .id(Calendar.current.startOfDay(for: selectedDate))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        // 与头部「删除」按钮行为一致；文本框聚焦时 Delete 键由文本框处理。
        .onDeleteCommand(perform: requestDeleteSelectedTask)
        // This view lives in the Workspace split-view detail column; keep its
        // sizing flexible and let the window/container own minimum dimensions.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "删除这条日程？",
            isPresented: Binding(
                get: { pendingDeleteTask != nil },
                set: { if !$0 { pendingDeleteTask = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除日程", role: .destructive, action: confirmPendingDelete)
            Button("取消", role: .cancel) { pendingDeleteTask = nil }
        } message: {
            Text("删除后无法恢复。关联的四象限任务会保留。")
        }
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

    private func requestDeleteSelectedTask() {
        guard let selectedTask else { return }
        requestDelete(selectedTask)
    }

    private func requestDelete(_ task: DailyTask) {
        pendingDeleteTask = task
    }

    /// 用户确认后才真正删除，并清理仍指向该日程的选中状态。
    private func confirmPendingDelete() {
        guard let task = pendingDeleteTask else { return }
        let id = task.id
        pendingDeleteTask = nil
        if taskStore.removeDailyTask(task), selectedTask?.id == id { selectedTask = nil }
    }
}

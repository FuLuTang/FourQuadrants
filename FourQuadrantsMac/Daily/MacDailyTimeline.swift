import SwiftData
import SwiftUI

struct MacDailyTimeline: View {
    @Environment(TaskStore.self) private var taskStore
    @Query private var tasks: [DailyTask]

    let date: Date
    let selectedTaskID: UUID?
    let onSelect: (DailyTask) -> Void
    let onEdit: (DailyTask) -> Void
    let onDelete: (DailyTask) -> Void
    let onNew: (Date) -> Void
    /// 单击时间轴空白处时调用，用于取消选中。
    let onDeselect: () -> Void

    /// View-local drag state. Models stay untouched until the gesture ends.
    @State private var dragPreview: MacDailyDragPreview?

    private typealias Metrics = MacDailyTimelineMetrics

    init(date: Date, selectedTaskID: UUID?, onSelect: @escaping (DailyTask) -> Void, onEdit: @escaping (DailyTask) -> Void, onDelete: @escaping (DailyTask) -> Void, onNew: @escaping (Date) -> Void, onDeselect: @escaping () -> Void) {
        self.date = date
        self.selectedTaskID = selectedTaskID
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onNew = onNew
        self.onDeselect = onDeselect

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let queryStart = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        let end = MacDailyTimeMath.dayEnd(of: start)
        _tasks = Query(
            filter: #Predicate<DailyTask> { task in task.startAt >= queryStart && task.startAt < end },
            sort: [SortDescriptor(\.startAt)]
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                GeometryReader { geometry in
                    let dayStart = Calendar.current.startOfDay(for: date)
                    let dayEnd = MacDailyTimeMath.dayEnd(of: dayStart)
                    let visibleTasks = tasks.filter { $0.endAt > dayStart }
                    let layout = MacDailyTimelineLayout.calculate(tasks: visibleTasks, dayStart: dayStart, dayEnd: dayEnd, hourHeight: Metrics.hourHeight)
                    let contentWidth = geometry.size.width
                    let blocksWidth = max(contentWidth - Metrics.timeColumnWidth - Metrics.blocksTrailingInset, Metrics.minBlocksWidth)

                    ZStack(alignment: .topLeading) {
                        MacDailyHourGrid(
                            onEmptyDoubleClick: { y in
                                let minute = MacDailyTimeMath.snapped(Int((y / Metrics.hourHeight * 60).rounded()))
                                onNew(MacDailyTimeMath.date(on: dayStart, minute: min(minute, MacDailyTimeMath.latestNewTaskMinute)))
                            },
                            onEmptySingleClick: onDeselect
                        )

                        if visibleTasks.isEmpty {
                            emptyState
                                .position(x: Metrics.timeColumnWidth + blocksWidth / 2, y: Metrics.emptyStateHour * Metrics.hourHeight)
                        }

                        ForEach(layout) { item in
                            block(for: item, dayStart: dayStart, blocksWidth: blocksWidth)
                        }

                        MacDailyCurrentTimeLine(date: date)
                            .allowsHitTesting(false)
                    }
                    .coordinateSpace(name: Metrics.coordinateSpace)
                    .frame(width: contentWidth, height: Metrics.timelineHeight, alignment: .topLeading)
                }
                .frame(height: Metrics.timelineHeight)
                .padding(.trailing, Metrics.scrollTrailingPadding)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onAppear { scrollToRelevantHour(using: proxy) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 27))
                .foregroundStyle(.tint)
            Text("这一天还没有日程")
                .font(.headline)
            Text("双击时间轴空白处，按 15 分钟间隔快速新建。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("示例：周会、专注工作、午休、接孩子")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private func block(for item: MacDailyTimelineLayout.Item, dayStart: Date, blocksWidth: CGFloat) -> some View {
        let preview = dragPreview?.taskID == item.id ? dragPreview?.layout : nil
        let startAt = preview?.startAt ?? item.startAt
        let duration = preview?.duration ?? item.duration
        let frame = preview.map {
            MacDailyTimelineLayout.previewFrame(
                columnFrame: item.frame,
                startAt: $0.startAt,
                duration: $0.duration,
                dayStart: dayStart,
                hourHeight: Metrics.hourHeight
            )
        } ?? item.frame
        let width = blocksWidth * frame.width
        let height = max(frame.height, Metrics.minBlockHeight)
        let x = Metrics.timeColumnWidth + Metrics.blocksLeadingGap + frame.minX * blocksWidth + width / 2
        let y = frame.minY + height / 2

        return MacDailyTaskBlock(
            task: item.task,
            date: date,
            hourHeight: Metrics.hourHeight,
            displayStartAt: startAt,
            displayDuration: duration,
            isSelected: selectedTaskID == item.id,
            onSelect: { onSelect(item.task) },
            onEdit: { onEdit(item.task) },
            onDelete: { onDelete(item.task) },
            onLayoutPreview: { dragPreview = MacDailyDragPreview(taskID: item.id, layout: $0) },
            onLayoutCommit: { commit($0, for: item.task) },
            onLayoutCancel: { dragPreview = nil }
        )
        .frame(width: max(width - Metrics.blockWidthInset, Metrics.minBlockWidth), height: height)
        .position(x: x, y: y)
    }

    /// Writes the dragged layout to the model in a single save.
    private func commit(_ layout: MacDailyLayoutProposal, for task: DailyTask) {
        defer { dragPreview = nil }
        guard layout.startAt != task.startAt || layout.duration != task.duration else { return }
        _ = taskStore.moveDailyTask(task, startAt: layout.startAt, duration: layout.duration)
    }

    private func scrollToRelevantHour(using proxy: ScrollViewProxy) {
        let calendar = Calendar.current
        let hour = calendar.isDateInToday(date) ? calendar.component(.hour, from: .now) : Metrics.defaultScrollHour
        withAnimation(.snappy(duration: 0.28)) { proxy.scrollTo(Metrics.hourID(hour), anchor: .center) }
    }
}

private struct MacDailyDragPreview: Equatable {
    let taskID: UUID
    let layout: MacDailyLayoutProposal
}

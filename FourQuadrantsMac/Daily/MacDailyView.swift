import SwiftData
import SwiftUI
import AppKit

private struct MacDailyTaskPresentation: Identifiable {
    let id = UUID()
    let task: DailyTask?
    let selectedDate: Date
    let initialStartAt: Date
}

/// Native macOS daily planner. The host supplies the shared SwiftData container
/// and the shared `TaskStore` through the environment.
public struct MacDailyView: View {
    @Environment(TaskStore.self) private var taskStore
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var selectedTask: DailyTask?
    @State private var taskPresentation: MacDailyTaskPresentation?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            MacDailyHeader(
                date: selectedDate,
                hasSelection: selectedTask != nil,
                isSelectionCompleted: selectedTask?.isCompleted ?? false,
                onPrevious: { changeDay(by: -1) },
                onNext: { changeDay(by: 1) },
                onToday: { selectToday() },
                onDateChange: { selectedDate = Calendar.current.startOfDay(for: $0) },
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
            return MacDailyTimeMath.date(on: dayStart, minute: min(minute, 23 * 60 + 45))
        }
        return MacDailyTimeMath.date(on: dayStart, minute: 9 * 60)
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

private struct MacDailyHeader: View {
    let date: Date
    let hasSelection: Bool
    let isSelectionCompleted: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    let onDateChange: (Date) -> Void
    let onNew: () -> Void
    let onEdit: () -> Void
    let onToggleCompletion: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                .help("前一天")
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                DatePicker("日期", selection: Binding(get: { date }, set: onDateChange), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: 190)
                    .accessibilityLabel("选择日期")

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
                .help("后一天")
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("今天", action: onToday)
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.title3.weight(.semibold))
                Text(date.formatted(.dateTime.year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            if hasSelection {
                Button(isSelectionCompleted ? "标为未完成" : "标为完成", systemImage: "checkmark.circle") { onToggleCompletion() }
                    .help("切换日程完成状态")
                Button("编辑", systemImage: "pencil", action: onEdit)
                    .keyboardShortcut("e", modifiers: [.command])
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
                .help("删除所选日程")
            }

            Button(action: onNew) {
                Label("新建日程", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: [.command])
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }
}

private struct MacDailyTimeline: View {
    @Query private var tasks: [DailyTask]

    let date: Date
    let selectedTaskID: UUID?
    let onSelect: (DailyTask) -> Void
    let onEdit: (DailyTask) -> Void
    let onDelete: (DailyTask) -> Void
    let onNew: (Date) -> Void

    private let hourHeight: CGFloat = 64
    private let timeColumnWidth: CGFloat = 72
    private let timelineHeight: CGFloat = 24 * 64

    init(date: Date, selectedTaskID: UUID?, onSelect: @escaping (DailyTask) -> Void, onEdit: @escaping (DailyTask) -> Void, onDelete: @escaping (DailyTask) -> Void, onNew: @escaping (Date) -> Void) {
        self.date = date
        self.selectedTaskID = selectedTaskID
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onNew = onNew

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let queryStart = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 3600)
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
                    let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
                    let visibleTasks = tasks.filter { $0.endAt > dayStart }
                    let layout = MacDailyTimelineLayout.calculate(tasks: visibleTasks, dayStart: dayStart, dayEnd: dayEnd, hourHeight: hourHeight)
                    let contentWidth = geometry.size.width
                    let blocksWidth = max(contentWidth - timeColumnWidth - 28, 220)

                    ZStack(alignment: .topLeading) {
                        MacDailyHourGrid(hourHeight: hourHeight, timeColumnWidth: timeColumnWidth, onEmptyClick: { y in
                            let minute = MacDailyTimeMath.snapped(Int((y / hourHeight * 60).rounded()))
                            onNew(MacDailyTimeMath.date(on: dayStart, minute: min(minute, 23 * 60 + 45)))
                        })

                        if visibleTasks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 27))
                                    .foregroundStyle(.tint)
                                Text("这一天还没有日程")
                                    .font(.headline)
                                Text("单击时间轴空白处，按 15 分钟间隔快速新建。")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text("示例：周会、专注工作、午休、接孩子")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .position(x: timeColumnWidth + blocksWidth / 2, y: 9.5 * hourHeight)
                            .allowsHitTesting(false)
                        }

                        ForEach(layout) { item in
                            let width = blocksWidth * item.frame.width
                            let height = max(item.frame.height, 22)
                            let x = timeColumnWidth + 12 + item.frame.minX * blocksWidth + width / 2
                            let y = item.frame.minY + height / 2

                            MacDailyTaskBlock(
                                task: item.task,
                                date: date,
                                hourHeight: hourHeight,
                                displayStartAt: item.startAt,
                                displayDuration: item.duration,
                                isSelected: selectedTaskID == item.id,
                                onSelect: { onSelect(item.task) },
                                onEdit: { onEdit(item.task) },
                                onDelete: { onDelete(item.task) }
                            )
                            .frame(width: max(width - 3, 48), height: height)
                            .position(x: x, y: y)
                        }

                        MacDailyCurrentTimeLine(date: date, hourHeight: hourHeight, timeColumnWidth: timeColumnWidth)
                            .allowsHitTesting(false)
                    }
                    .frame(width: contentWidth, height: timelineHeight, alignment: .topLeading)
                }
                .frame(height: timelineHeight)
                .padding(.trailing, 18)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onAppear { scrollToRelevantHour(using: proxy) }
            .onChange(of: date) { _, _ in scrollToRelevantHour(using: proxy) }
        }
    }

    private func scrollToRelevantHour(using proxy: ScrollViewProxy) {
        let calendar = Calendar.current
        let hour = calendar.isDateInToday(date) ? calendar.component(.hour, from: .now) : 8
        withAnimation(.snappy(duration: 0.28)) { proxy.scrollTo("hour-\(hour)", anchor: .center) }
    }
}

private struct MacDailyHourGrid: View {
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat
    let onEmptyClick: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(.caption, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth - 12, alignment: .trailing)
                        .padding(.trailing, 12)
                        .offset(y: -8)

                    Rectangle()
                        .fill(Color.primary.opacity(0.11))
                        .frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
                .id("hour-\(hour)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 24 * hourHeight, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { point in onEmptyClick(point.y) }
        .accessibilityHint("单击空白时间段可按 15 分钟间隔新建日程")
    }
}

private struct MacDailyTaskBlock: View {
    @Environment(TaskStore.self) private var taskStore

    let task: DailyTask
    let date: Date
    let hourHeight: CGFloat
    let displayStartAt: Date
    let displayDuration: TimeInterval
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var dragOrigin: (start: Date, duration: TimeInterval)?

    var body: some View {
        let color = MacDailyPalette.color(hex: task.colorHex)
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                Text(task.title.isEmpty ? "未命名日程" : task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if task.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                }
            }
            if displayDuration >= 35 * 60 {
                Text("\(displayStartAt.formatted(date: .omitted, time: .shortened)) – \(displayStartAt.addingTimeInterval(displayDuration).formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .opacity(0.88)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(task.isCompleted ? 0.53 : 0.92), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isSelected ? Color.primary.opacity(0.9) : .white.opacity(0.24), lineWidth: isSelected ? 2 : 0.75)
        }
        .overlay(alignment: .top) { resizeGrip.opacity(0.75).padding(.top, 3) }
        .overlay(alignment: .bottom) { resizeGrip.opacity(0.75).padding(.bottom, 3) }
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onTapGesture(count: 1, perform: onSelect)
        .onTapGesture(count: 2, perform: onEdit)
        .gesture(moveGesture)
        .overlay(alignment: .topTrailing) {
            Button {
                // Matches iOS DailyTaskBlock: completion changes this DailyTask only.
                _ = taskStore.toggleDailyTask(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "标为未完成" : "标为完成")
            .offset(x: -1, y: 1)
        }
        .overlay(alignment: .top) {
            HStack {
                Spacer()
                resizeHitZone(isTop: true)
                    .frame(width: 42)
                Spacer()
            }
        }
        .overlay(alignment: .bottom) {
            HStack {
                Spacer()
                resizeHitZone(isTop: false)
                    .frame(width: 42)
                Spacer()
            }
        }
        .contextMenu {
            Button("编辑…", systemImage: "pencil", action: onEdit)
            Button(task.isCompleted ? "标为未完成" : "标为完成", systemImage: "checkmark.circle") {
                _ = taskStore.toggleDailyTask(task)
            }
            Divider()
            Button("删除日程", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(task.title)
        .accessibilityValue(task.isCompleted ? "已完成" : "未完成")
    }

    private var resizeGrip: some View {
        Capsule().fill(.white.opacity(0.75)).frame(width: 22, height: 3).allowsHitTesting(false)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOrigin == nil { dragOrigin = (task.startAt, task.duration) }
                guard let origin = dragOrigin else { return }
                let delta = Int((value.translation.height / hourHeight * 60).rounded())
                guard origin.duration <= 24 * 3600 else { return }
                let latestStart = max(0, 24 * 60 - Int((origin.duration / 60).rounded(.up)))
                let snappedLatestStart = latestStart / MacDailyTimeMath.snapMinutes * MacDailyTimeMath.snapMinutes
                let startMinute = min(max(MacDailyTimeMath.snapped(MacDailyTimeMath.minuteOfDay(displayStartAt) + delta), 0), snappedLatestStart)
                let newStart = MacDailyTimeMath.date(on: date, minute: startMinute)
                taskStore.previewDailyTaskLayout(task, startAt: newStart, duration: origin.duration)
            }
            .onEnded { _ in finishLayoutGesture() }
    }

    @ViewBuilder
    private func resizeHitZone(isTop: Bool) -> some View {
        if taskFitsVisibleDay {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 9)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if dragOrigin == nil { dragOrigin = (task.startAt, task.duration) }
                            guard let origin = dragOrigin else { return }
                            resize(origin: origin, deltaY: value.translation.height, isTop: isTop)
                        }
                        .onEnded { _ in finishLayoutGesture() }
                )
                .accessibilityLabel(isTop ? "拖动以调整开始时间" : "拖动以调整结束时间")
        }
    }

    private var taskFitsVisibleDay: Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
        return task.startAt >= dayStart && task.endAt <= dayEnd
    }

    private func resize(origin: (start: Date, duration: TimeInterval), deltaY: CGFloat, isTop: Bool) {
        let startMinute = MacDailyTimeMath.minuteOfDay(origin.start)
        if isTop {
            let oldEnd = origin.start.addingTimeInterval(origin.duration)
            let requested = MacDailyTimeMath.snapped(startMinute + Int((deltaY / hourHeight * 60).rounded()))
            let latestStartMinute = MacDailyTimeMath.minuteOfDay(oldEnd.addingTimeInterval(-MacDailyTimeMath.minimumDuration))
            let newStartMinute = min(requested, latestStartMinute)
            let newStart = MacDailyTimeMath.date(on: date, minute: max(newStartMinute, 0))
            taskStore.previewDailyTaskLayout(task, startAt: newStart, duration: max(oldEnd.timeIntervalSince(newStart), MacDailyTimeMath.minimumDuration))
        } else {
            let requestedEnd = MacDailyTimeMath.snapped(startMinute + Int((origin.duration / 60).rounded()) + Int((deltaY / hourHeight * 60).rounded()))
            let endMinute = min(max(requestedEnd, startMinute + Int(MacDailyTimeMath.minimumDuration / 60)), 24 * 60)
            let end = endMinute == 24 * 60 ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))! : MacDailyTimeMath.date(on: date, minute: endMinute)
            taskStore.previewDailyTaskLayout(task, startAt: origin.start, duration: max(end.timeIntervalSince(origin.start), MacDailyTimeMath.minimumDuration))
        }
    }

    private func finishLayoutGesture() {
        if !taskStore.commitDailyTaskLayout(task), let origin = dragOrigin {
            taskStore.restoreDailyTaskLayout(task, startAt: origin.start, duration: origin.duration)
        }
        dragOrigin = nil
    }
}

private struct MacDailyCurrentTimeLine: View {
    let date: Date
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if Calendar.current.isDate(context.date, inSameDayAs: date) {
                let minute = CGFloat(MacDailyTimeMath.minuteOfDay(context.date))
                HStack(spacing: 8) {
                    Text(context.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.red)
                        .frame(width: timeColumnWidth - 10, alignment: .trailing)
                    Rectangle().fill(.red.opacity(0.78)).frame(height: 1.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: minute / 60 * hourHeight)
            }
        }
    }
}

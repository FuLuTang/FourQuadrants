import SwiftData
import SwiftUI

struct MacDailyTaskFormView: View {
    @Environment(TaskStore.self) private var taskStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QuadrantTask.updatedAt, order: .reverse) private var quadrantTasks: [QuadrantTask]

    let task: DailyTask?
    let selectedDate: Date
    let onSave: ((DailyTask?) -> Void)?

    @State private var title: String
    @State private var startAt: Date
    @State private var duration: TimeInterval
    @State private var colorHex: String
    @State private var notes: String
    @State private var selectedQuadrantTaskID: UUID?
    @State private var isShowingQuadrantPicker = false
    @State private var isShowingDeleteConfirmation = false
    @State private var suggestionIndex = MacDailyTaskSuggestions.Index(tasks: [])
    @State private var suggestions: [MacDailyTaskSuggestions.Suggestion] = []
    @FocusState private var isTitleFocused: Bool

    private static let visibleSuggestionCount = 3
    private static let suggestionDebounce: Duration = .milliseconds(250)

    private struct SuggestionKey: Equatable {
        let title: String
        let notes: String
        let taskStamp: [MacDailyTaskSuggestions.Stamp]
    }

    init(task: DailyTask?, selectedDate: Date, initialStartAt: Date, onSave: ((DailyTask?) -> Void)? = nil) {
        self.task = task
        self.selectedDate = selectedDate
        self.onSave = onSave

        let start = task?.startAt ?? initialStartAt
        _title = State(initialValue: task?.title ?? "")
        _startAt = State(initialValue: start)
        _duration = State(initialValue: task?.duration ?? 3600)
        _colorHex = State(initialValue: task?.colorHex ?? MacDailyPalette.taskColors[0])
        _notes = State(initialValue: task?.notes ?? "")
        _selectedQuadrantTaskID = State(initialValue: task?.quadrantTask?.id)
    }

    private var linkedTask: QuadrantTask? {
        quadrantTasks.first { $0.id == selectedQuadrantTaskID }
    }

    /// Suggestions shown under the link section, never including the linked task.
    private var visibleSuggestions: [MacDailyTaskSuggestions.Suggestion] {
        suggestions
            .filter { $0.task.id != selectedQuadrantTaskID }
            .prefix(Self.visibleSuggestionCount)
            .map { $0 }
    }

    private var suggestionKey: SuggestionKey {
        SuggestionKey(title: title, notes: notes, taskStamp: MacDailyTaskSuggestions.stamp(of: quadrantTasks))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task == nil ? "新建日程" : "编辑日程")
                        .font(.title2.weight(.semibold))
                    Text(startAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(22)

            Divider()

            Form {
                Section("日程内容") {
                    TextField("例如：完成周报、复习 SwiftData", text: $title)
                        .font(.title3)
                        .focused($isTitleFocused)
                        .onSubmit(save)
                    Text("清楚写下要做的事，后续可在时间轴上直接拖动调整。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("日期与时间") {
                    DatePicker("日期", selection: $startAt, displayedComponents: .date)
                    DatePicker("开始", selection: $startAt, displayedComponents: .hourAndMinute)
                    DatePicker("结束", selection: endAtBinding, displayedComponents: .hourAndMinute)

                    if !Calendar.current.isDate(startAt, inSameDayAs: startAt.addingTimeInterval(duration)) {
                        Label("结束时间延续至次日", systemImage: "moon.stars")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }

                    HStack(spacing: 8) {
                        Text("时长：\(MacDailyTimeMath.durationText(minutes: Int(duration / 60)))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Button(MacDailyTimeMath.durationText(minutes: minutes)) {
                                duration = TimeInterval(minutes * 60)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .font(.callout)
                }

                Section("颜色") {
                    HStack(spacing: 11) {
                        ForEach(MacDailyPalette.taskColors, id: \.self) { color in
                            Button {
                                colorHex = color
                            } label: {
                                Circle()
                                    .fill(MacDailyPalette.color(hex: color))
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if colorHex == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(3)
                                    .overlay {
                                        Circle().strokeBorder(colorHex == color ? Color.primary.opacity(0.85) : .clear, lineWidth: 1.5)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("选择日程颜色")
                        }
                        Spacer()
                    }
                }

                Section("备注") {
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 78)
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("例如：带上会议材料，提前 10 分钟到场。")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 7)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section {
                    MacDailyLinkedTaskSection(
                        linkedTask: linkedTask,
                        suggestions: visibleSuggestions,
                        hasSearchableTasks: !quadrantTasks.isEmpty,
                        onChoose: { selectedQuadrantTaskID = $0.id },
                        onUnlink: { selectedQuadrantTaskID = nil },
                        onOpenPicker: { isShowingQuadrantPicker = true }
                    )
                } header: {
                    Text("关联四象限任务")
                } footer: {
                    Text("关联只记录这条日程对应的任务；完成日程不会自动更改四象限任务状态。")
                }

                if task != nil {
                    Section {
                        Button("删除日程", systemImage: "trash", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(minWidth: 520, minHeight: 620)
        // 新建时直接聚焦标题框，编辑已有日程时不抢焦点。
        .onAppear { isTitleFocused = task == nil }
        .task(id: suggestionKey) { await refreshSuggestions() }
        .sheet(isPresented: $isShowingQuadrantPicker) {
            MacQuadrantTaskPicker(
                tasks: quadrantTasks,
                selectedID: selectedQuadrantTaskID,
                onSelect: { selected in
                    selectedQuadrantTaskID = selected?.id
                    isShowingQuadrantPicker = false
                }
            )
            .frame(minWidth: 440, minHeight: 440)
        }
        .confirmationDialog("删除这条日程？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除日程", role: .destructive, action: deleteTask)
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。关联的四象限任务会保留。")
        }
    }

    private var endAtBinding: Binding<Date> {
        Binding(
            get: { startAt.addingTimeInterval(duration) },
            set: { proposedEnd in
                let components = Calendar.current.dateComponents([.hour, .minute], from: proposedEnd)
                let calendar = Calendar.current
                let dayStart = calendar.startOfDay(for: startAt)
                var end = calendar.date(
                    bySettingHour: components.hour ?? 0,
                    minute: components.minute ?? 0,
                    second: 0,
                    of: dayStart,
                    matchingPolicy: .nextTime
                ) ?? proposedEnd
                if end <= startAt {
                    end = calendar.date(byAdding: .day, value: 1, to: end) ?? end.addingTimeInterval(MacDailyTimeMath.maximumDuration)
                }
                duration = min(max(end.timeIntervalSince(startAt), MacDailyTimeMath.minimumDuration), MacDailyTimeMath.maximumDuration)
            }
        )
    }

    /// Debounced so typing does not re-rank every task on each keystroke.
    private func refreshSuggestions() async {
        let key = suggestionKey
        guard !key.title.isEmpty || !key.notes.isEmpty else {
            suggestions = []
            return
        }
        try? await Task.sleep(for: Self.suggestionDebounce)
        guard !Task.isCancelled else { return }
        if suggestionIndex.stamp != key.taskStamp {
            suggestionIndex = MacDailyTaskSuggestions.Index(tasks: quadrantTasks)
        }
        suggestions = MacDailyTaskSuggestions.ranked(
            title: key.title,
            notes: key.notes,
            in: suggestionIndex,
            limit: Self.visibleSuggestionCount + 1
        )
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let linkedTask = linkedTask

        let savedTask: DailyTask?
        if let task {
            let didSave = taskStore.updateDailyTask(
                task,
                title: cleanTitle,
                startAt: startAt,
                duration: min(max(duration, MacDailyTimeMath.minimumDuration), MacDailyTimeMath.maximumDuration),
                colorHex: colorHex,
                notes: notes,
                quadrantTask: linkedTask
            )
            savedTask = didSave ? task : nil
        } else {
            savedTask = taskStore.createDailyTask(
                title: cleanTitle,
                startAt: startAt,
                duration: min(max(duration, MacDailyTimeMath.minimumDuration), MacDailyTimeMath.maximumDuration),
                colorHex: colorHex,
                notes: notes,
                quadrantTask: linkedTask
            )
        }
        if let savedTask {
            onSave?(savedTask)
            dismiss()
        }
    }

    private func deleteTask() {
        guard let task, taskStore.removeDailyTask(task) else { return }
        dismiss()
    }
}

import SwiftData
import SwiftUI
import AppKit

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

    private var suggestions: [MacDailyTaskSuggestions.Suggestion] {
        MacDailyTaskSuggestions.ranked(title: title, notes: notes, among: quadrantTasks)
            .filter { $0.task.id != selectedQuadrantTaskID }
            .prefix(3)
            .map { $0 }
    }

    private var durationDescription: String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) 分钟" }
        if minutes == 0 { return "\(hours) 小时" }
        return "\(hours) 小时 \(minutes) 分钟"
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
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(22)

            Divider()

            Form {
                Section("日程内容") {
                    TextField("例如：完成周报、复习 SwiftData", text: $title)
                        .font(.title3)
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
                        Text("时长：\(durationDescription)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Button(durationTitle(minutes)) {
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
                        suggestions: suggestions,
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
                    end = calendar.date(byAdding: .day, value: 1, to: end) ?? end.addingTimeInterval(24 * 3600)
                }
                duration = min(max(end.timeIntervalSince(startAt), MacDailyTimeMath.minimumDuration), 24 * 3600)
            }
        )
    }

    private func durationTitle(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remaining = minutes % 60
        if hours == 0 { return "\(minutes) 分钟" }
        if remaining == 0 { return "\(hours) 小时" }
        return "\(hours) 小时 \(remaining) 分钟"
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
                duration: min(max(duration, MacDailyTimeMath.minimumDuration), 24 * 3600),
                colorHex: colorHex,
                notes: notes,
                quadrantTask: linkedTask
            )
            savedTask = didSave ? task : nil
        } else {
            savedTask = taskStore.createDailyTask(
                title: cleanTitle,
                startAt: startAt,
                duration: min(max(duration, MacDailyTimeMath.minimumDuration), 24 * 3600),
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

private struct MacDailyLinkedTaskSection: View {
    let linkedTask: QuadrantTask?
    let suggestions: [MacDailyTaskSuggestions.Suggestion]
    let hasSearchableTasks: Bool
    let onChoose: (QuadrantTask) -> Void
    let onUnlink: () -> Void
    let onOpenPicker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let linkedTask {
                MacQuadrantTaskCard(task: linkedTask, isLinked: true)
                Button("取消关联", systemImage: "link.badge.minus", action: onUnlink)
                    .buttonStyle(.borderless)
            } else {
                Label("尚未关联四象限任务", systemImage: "link")
                    .foregroundStyle(.secondary)
                Text("可先选择一条已有任务；这不会影响日程的独立创建与完成。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label("标题与备注关键词建议", systemImage: "sparkle.magnifyingglass")
                        .font(.subheadline.weight(.medium))
                    ForEach(suggestions) { suggestion in
                        Button {
                            onChoose(suggestion.task)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(suggestion.task.isCompleted ? Color.secondary : Color.accentColor)
                                    .frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.task.title)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                    Text("匹配：\(suggestion.matches.formatted())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if suggestion.task.isCompleted {
                                    Text("已完成").font(.caption).foregroundStyle(.secondary)
                                }
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if !hasSearchableTasks {
                ContentUnavailableView {
                    Label("还没有四象限任务", systemImage: "square.grid.2x2")
                } description: {
                    Text("你仍可保存这条日程，之后再从四象限任务中关联。")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } else {
                Text("输入标题或备注后，这里会显示关键词匹配建议。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(hasSearchableTasks ? "搜索并手动选择…" : "选择关联任务…", systemImage: "magnifyingglass", action: onOpenPicker)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

private struct MacQuadrantTaskPicker: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [QuadrantTask]
    let selectedID: UUID?
    let onSelect: (QuadrantTask?) -> Void

    @State private var searchText = ""

    private var filteredTasks: [QuadrantTask] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter {
            $0.title.localizedStandardContains(searchText) || ($0.notes ?? "").localizedStandardContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择四象限任务").font(.title2.weight(.semibold))
                    Text("手动选择始终可用，也可以取消关联。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            TextField("搜索任务标题或备注", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            List {
                Button {
                    onSelect(nil)
                } label: {
                    Label("不关联任务", systemImage: "link.badge.minus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if filteredTasks.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(filteredTasks, id: \.id) { task in
                        Button {
                            onSelect(task)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedID == task.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedID == task.id ? Color.accentColor : Color.secondary)
                                MacQuadrantTaskCard(task: task, isLinked: false)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct MacQuadrantTaskCard: View {
    let task: QuadrantTask
    let isLinked: Bool

    private var quadrantLabel: String {
        switch (task.isImportantQuadrant, task.isUrgent) {
        case (true, true): "重要且紧急"
        case (true, false): "重要不紧急"
        case (false, true): "紧急不重要"
        case (false, false): "不重要不紧急"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(task.title).font(.callout.weight(.medium)).lineLimit(1)
                if task.isCompleted {
                    Text("已完成").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 7) {
                Text(quadrantLabel)
                if let dueDate = task.displayDueDate {
                    Text("·")
                    Text("截止 \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if isLinked, let notes = task.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

private enum MacDailyTaskSuggestions {
    struct Suggestion: Identifiable {
        let task: QuadrantTask
        let matches: [String]
        let score: Double
        var id: UUID { task.id }
    }

    static func ranked(title: String, notes: String, among tasks: [QuadrantTask]) -> [Suggestion] {
        let sourceTerms = terms(title + " " + notes)
        guard !sourceTerms.isEmpty else { return [] }

        return tasks.compactMap { task in
            let candidateTerms = terms(task.title + " " + (task.notes ?? ""))
            let shared = sourceTerms.intersection(candidateTerms).sorted()
            guard !shared.isEmpty else { return nil }
            let unionCount = sourceTerms.union(candidateTerms).count
            let score = Double(shared.count) / Double(max(unionCount, 1))
            return Suggestion(task: task, matches: shared, score: score)
        }
        .sorted {
            if $0.score == $1.score {
                if $0.task.isCompleted != $1.task.isCompleted { return !$0.task.isCompleted }
                return $0.task.updatedAt > $1.task.updatedAt
            }
            return $0.score > $1.score
        }
    }

    private static func terms(_ text: String) -> Set<String> {
        let scalars = text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let characters = Array(String(String.UnicodeScalarView(scalars)))
        guard characters.count > 1 else { return [] }

        var result = Set<String>()
        for width in 2...min(3, characters.count) {
            for start in 0...(characters.count - width) {
                result.insert(String(characters[start..<(start + width)]))
            }
        }
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 }
        result.formUnion(words)
        return result
    }
}

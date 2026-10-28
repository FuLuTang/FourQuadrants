import SwiftUI

/// One task on the timeline. Move and resize gestures only report proposed
/// layouts; the owner decides when to write them to the model.
struct MacDailyTaskBlock: View {
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
    let onLayoutPreview: (MacDailyLayoutProposal) -> Void
    let onLayoutCommit: (MacDailyLayoutProposal) -> Void
    let onLayoutCancel: () -> Void

    /// Values captured when a drag begins; every update is computed from these.
    private struct DragOrigin {
        let start: Date
        let displayStart: Date
        let duration: TimeInterval
    }

    @State private var dragOrigin: DragOrigin?
    @State private var latestProposal: MacDailyLayoutProposal?

    private typealias Metrics = MacDailyTimelineMetrics

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.blockCornerRadius, style: .continuous)
    }

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
            if displayDuration >= Metrics.timeRangeMinDuration {
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
        .background(color.opacity(task.isCompleted ? 0.53 : 0.92), in: shape)
        .overlay {
            shape.strokeBorder(isSelected ? Color.primary.opacity(0.9) : .white.opacity(0.24), lineWidth: isSelected ? 2 : 0.75)
        }
        .overlay(alignment: .top) { resizeGrip.opacity(0.75).padding(.top, Metrics.resizeGripInset) }
        .overlay(alignment: .bottom) { resizeGrip.opacity(0.75).padding(.bottom, Metrics.resizeGripInset) }
        .contentShape(shape)
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
        .overlay(alignment: .top) { centeredResizeZone(isTop: true) }
        .overlay(alignment: .bottom) { centeredResizeZone(isTop: false) }
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

    private func centeredResizeZone(isTop: Bool) -> some View {
        HStack {
            Spacer()
            resizeHitZone(isTop: isTop)
                .frame(width: Metrics.resizeHitZoneWidth)
            Spacer()
        }
    }

    // MARK: Gestures

    private func dragGesture(minimumDistance: CGFloat, proposal: @escaping (DragOrigin, CGFloat) -> MacDailyLayoutProposal?) -> some Gesture {
        // Measured in the timeline's coordinate space: the block moves under the
        // pointer while previewing, which would skew a local translation.
        DragGesture(minimumDistance: minimumDistance, coordinateSpace: .named(Metrics.coordinateSpace))
            .onChanged { value in
                let origin = dragOrigin ?? DragOrigin(start: task.startAt, displayStart: displayStartAt, duration: task.duration)
                dragOrigin = origin
                guard let next = proposal(origin, value.location.y - value.startLocation.y) else { return }
                latestProposal = next
                onLayoutPreview(next)
            }
            .onEnded { _ in finishLayoutGesture() }
    }

    private var moveGesture: some Gesture {
        dragGesture(minimumDistance: Metrics.moveGestureMinimumDistance) { origin, deltaY in
            MacDailyDragMath.moved(
                displayStart: origin.displayStart,
                duration: origin.duration,
                deltaY: deltaY,
                hourHeight: hourHeight,
                day: date
            )
        }
    }

    @ViewBuilder
    private func resizeHitZone(isTop: Bool) -> some View {
        if taskFitsVisibleDay {
            Rectangle()
                .fill(Color.clear)
                .frame(height: Metrics.resizeHitZoneHeight)
                .contentShape(Rectangle())
                .gesture(
                    dragGesture(minimumDistance: Metrics.resizeGestureMinimumDistance) { origin, deltaY in
                        isTop
                            ? MacDailyDragMath.resizedTop(start: origin.start, duration: origin.duration, deltaY: deltaY, hourHeight: hourHeight, day: date)
                            : MacDailyDragMath.resizedBottom(start: origin.start, duration: origin.duration, deltaY: deltaY, hourHeight: hourHeight, day: date)
                    }
                )
                .accessibilityLabel(isTop ? "拖动以调整开始时间" : "拖动以调整结束时间")
        }
    }

    private var taskFitsVisibleDay: Bool {
        let dayStart = Calendar.current.startOfDay(for: date)
        return task.startAt >= dayStart && task.endAt <= MacDailyTimeMath.dayEnd(of: dayStart)
    }

    private func finishLayoutGesture() {
        defer {
            dragOrigin = nil
            latestProposal = nil
        }
        if let latestProposal {
            onLayoutCommit(latestProposal)
        } else {
            onLayoutCancel()
        }
    }
}

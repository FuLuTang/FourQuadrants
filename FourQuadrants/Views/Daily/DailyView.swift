import SwiftUI
import SwiftData
import Combine

struct DailyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate: Date = Date()
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showAddTaskSheet = false // Add Sheet State
    
    // MARK: - Constants
    private let hourHeight: CGFloat = 60
    private let timeColumnWidth: CGFloat = 50
    private let startHour = 0
    private let endHour = 24
    
    var body: some View {
        // 时间轴滚动区域（全屏）
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // 背景网格 & 时间标签
                    timeGrid
                    
                    // 任务块 (这里需要查询当天的任务)
                    DailyTasksLayer(selectedDate: selectedDate, hourHeight: hourHeight, timeColumnWidth: timeColumnWidth)
                    
                    // 当前时间红线 (只在今天显示)
                    if Calendar.current.isDateInToday(selectedDate) {
                        CurrentTimeLine(hourHeight: hourHeight, timeColumnWidth: timeColumnWidth)
                    }
                }
                .frame(height: CGFloat(endHour - startHour) * hourHeight + 20) // +20 padding
                .padding(.top, 60) // 为顶部浮动的 dateHeader 留出空间
                .padding(.bottom, 80) // 底部留白给 FAB
            }
            .onAppear {
                scrollProxy = proxy
                scrollToCurrentTime()
            }
        }
        // 日期导航栏（浮动在顶部）
        .overlay(alignment: .top) {
            dateHeader
        }
        .overlay(alignment: .bottomTrailing) {
            // 右下角添加按钮
            Button {
                showAddTaskSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .glassEffect(
                        .clear.tint(.blue).interactive(),
                        in: .circle
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
            }
            .padding()
        }
        .sheet(isPresented: $showAddTaskSheet) {
            DailyTaskFormView(selectedDate: selectedDate)
        }
        .overlay(alignment: .bottomLeading) {
            // 左下角“回到当前”按钮
            Button {
                withAnimation {
                    selectedDate = Date()
                    scrollToCurrentTime()
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .glassEffect(
                        //.clear.tint(.white)
                        .clear.interactive(),
                        in: .circle
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
            }
            .padding()
        }
        // 监听 tab 重复点击（通过 notification）
        .onReceive(NotificationCenter.default.publisher(for: .scrollDailyToNow)) { _ in
            if Calendar.current.isDateInToday(selectedDate) {
                scrollToCurrentTime()
            } else {
                // 如果不是今天，先跳到今天再滚动
                withAnimation {
                    selectedDate = Date()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToCurrentTime()
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var dateHeader: some View {
        HStack {
            Spacer() // 确保整体居中
            
            // --- 居中的液态玻璃块 ---
            HStack(spacing: 0) {
                // 1. 左切换按钮
                Button {
                    changeDate(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.bold())
                        .padding(.leading, 16)
                        .padding(.trailing, 8)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle()) // 扩大点击区域
                }
                .buttonStyle(.plain) // 保持玻璃原始质感

                // 2. 文字部分（支持滑动）
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .frame(minWidth: 120) // 给滑动留出足够的感应区域
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    // --- 核心滑动逻辑 ---
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let threshold: CGFloat = 40
                                if value.translation.width < -threshold {
                                    changeDate(by: 1) // 向左滑，看未来
                                } else if value.translation.width > threshold {
                                    changeDate(by: -1) // 向右滑，回过去
                                }
                            }
                    )
                    .onTapGesture {
                        withAnimation(.spring()) { selectedDate = Date() }
                    }

                // 3. 右切换按钮
                Button {
                    changeDate(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.bold())
                        .padding(.trailing, 16)
                        .padding(.leading, 8)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            // --- iOS 26 液态玻璃样式 ---
            .glassEffect(
                .clear.tint(.white.opacity(0.1)).interactive(), 
                in: .capsule // 使用胶囊形更符合悬浮块的审美
            )
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            
            Spacer()
        }
        .padding(.top, 8)
        .zIndex(1)
    }

    // 辅助方法：带动画的日期切换
    private func changeDate(by days: Int) {
        // 使用 iOS 26 推荐的物理弹簧动画，模拟“推挤”玻璃的感觉
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        }
    }
    
    private var timeGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(spacing: 0) {
                    // 时间标签
                    Text(String(format: "%02d:00", hour))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: timeColumnWidth, alignment: .trailing)
                        .padding(.trailing, 8)
                        .offset(y: -7) // 稍微上移对齐线条
                    
                    // 分割线
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
        .padding(.top, 10)
    }
    
    private func scrollToCurrentTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        // 滚动到当前时间减去一点偏移，让红线在屏幕中间偏上
        withAnimation {
            scrollProxy?.scrollTo(max(0, hour - 2), anchor: .top)
        }
    }
}

// MARK: - Subviews

struct CurrentTimeLine: View {
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            timeLineContent(for: context.date)
        }
    }
    
    @ViewBuilder
    private func timeLineContent(for date: Date) -> some View {
        if Calendar.current.isDateInToday(date) {
            let calendar = Calendar.current
            let hour = CGFloat(calendar.component(.hour, from: date))
            let minute = CGFloat(calendar.component(.minute, from: date))
            let totalMinutes = hour * 60 + minute
            let yOffset = (totalMinutes / 60) * hourHeight + 10

            HStack(spacing: 4) {
                // --- 左侧时间胶囊 ---
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    // 透明玻璃效果
                    .glassEffect(
                        .regular.interactive(),
                        in: .capsule
                    )

                // --- 右侧红线 ---
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.red, .red.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
            }
            .padding(.leading, 4)
            .offset(y: yOffset)
            .zIndex(999)
        }
    }
}

// 独立的 Layer 用于查询数据
struct DailyTasksLayer: View {
    let selectedDate: Date
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat
    
    @Query private var tasks: [DailyTask]
    
    init(selectedDate: Date, hourHeight: CGFloat, timeColumnWidth: CGFloat) {
        self.selectedDate = selectedDate
        self.hourHeight = hourHeight
        self.timeColumnWidth = timeColumnWidth
        
        // 构造谓词查询当天的任务
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        self._tasks = Query(filter: #Predicate<DailyTask> { task in
            task.scheduledDate >= startOfDay && task.scheduledDate < endOfDay
        }, sort: \.startTime)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(tasks) { task in
                DailyTaskBlock(task: task, hourHeight: hourHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, timeColumnWidth + 8) // 让出时间轴
                    .padding(.trailing, 8)
                    // Offset逻辑移入 Block 内部处理，或者在这里处理静态位置
                    // 为了支持拖拽，Block 内部会处理偏移
                    .offset(y: calculateYOffset(for: task))
            }
        }
    }
    
    private func calculateYOffset(for task: DailyTask) -> CGFloat {
        let calendar = Calendar.current
        let hour = CGFloat(calendar.component(.hour, from: task.startTime))
        let minute = CGFloat(calendar.component(.minute, from: task.startTime))
        return ((hour * 60 + minute) / 60) * hourHeight + 10
    }
}

struct DailyTaskBlock: View {
    @Bindable var task: DailyTask
    let hourHeight: CGFloat
    @Environment(\.modelContext) private var modelContext
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    @State private var resizeOffset: CGFloat = 0
    @State private var isResizing = false
    
    @State private var showEditSheet = false
    
    var body: some View {
        // Fix: Explicitly convert 3600.0 to CGFloat
        // let height = (CGFloat(task.duration) / 3600.0) * hourHeight 
        // We will use displayHeight directly
        
        // Calculate offsets using State variables, not gesture value
        // let currentDragHours = isDragging ? (dragOffset / hourHeight) : 0
        let currentResizeHours = isResizing ? (resizeOffset / hourHeight) : 0
        
        // Dynamic duration for display
        // task.duration is Double, resizeOffset is CGFloat
        let displayDuration = isResizing ? max(900.0, task.duration + (Double(currentResizeHours) * 3600.0)) : task.duration
        let displayHeight = (CGFloat(displayDuration) / 3600.0) * hourHeight

        
        ZStack(alignment: .bottom) {
            // 任务主体
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: task.colorHex ?? "#5E81F4"))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        // 显示动态时间
                        let offsetSeconds = Double(dragOffset / hourHeight) * 3600.0
                        let displayStart = isDragging ? task.startTime.addingTimeInterval(offsetSeconds) : task.startTime
                        let displayEnd = displayStart.addingTimeInterval(displayDuration)
                        
                        Text("\(displayStart.formatted(date: .omitted, time: .shortened)) - \(displayEnd.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(6)
                }
            
            // 下边缘 Resize Handle
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isResizing = true
                            resizeOffset = value.translation.height
                        }
                        .onEnded { value in
                            // 提交时长修改 (吸附到 15 分钟)
                            let heightChangeRatio = Double(value.translation.height / hourHeight)
                            let rawDuration = task.duration + (heightChangeRatio * 3600.0)
                            
                            // Snapping to 15 mins (900 seconds)
                            let snappedDuration = round(rawDuration / 900.0) * 900.0
                            task.duration = max(900.0, snappedDuration)
                            
                            // 触发灵动岛更新
                            LiveActivityManager.shared.checkTask(context: modelContext)
                            
                            isResizing = false
                            resizeOffset = 0
                        }
                )
        }
        .frame(height: max(displayHeight, 20)) // Using dynamic height
        .shadow(color: isDragging ? .black.opacity(0.2) : .black.opacity(0.1), radius: isDragging ? 5 : 2, x: 0, y: isDragging ? 3 : 1)
        .offset(y: isDragging ? dragOffset : 0)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .onTapGesture {
            showEditSheet = true
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    // 提交开始时间修改 (吸附到 30 分钟)
                    let hoursShift = Double(value.translation.height / hourHeight)
                    let secondsShift = hoursShift * 3600.0
                    let rawNewDate = task.startTime.addingTimeInterval(secondsShift)
                    
                    // Snapping logic
                    let calendar = Calendar.current
                    let minute = calendar.component(.minute, from: rawNewDate)
                    let hour = calendar.component(.hour, from: rawNewDate)
                    
                    let totalMinutes = Double(hour * 60 + minute)
                    let snappedMinutes = round(totalMinutes / 30.0) * 30.0
                    
                    if let newStartDate = calendar.date(bySettingHour: Int(snappedMinutes) / 60, minute: Int(snappedMinutes) % 60, second: 0, of: rawNewDate) {
                        currentDurationWithAnimation(newStartDate: newStartDate)
                    }
                    
                    // 触发灵动岛更新
                    LiveActivityManager.shared.checkTask(context: modelContext)
                    
                    isDragging = false
                    dragOffset = 0
                }
        )
        .sheet(isPresented: $showEditSheet) {
            DailyTaskFormView(task: task, selectedDate: task.scheduledDate)
        }
    }

    
    // Helper to separate animation logic
    private func currentDurationWithAnimation(newStartDate: Date) {
        task.startTime = newStartDate
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let scrollDailyToNow = Notification.Name("scrollDailyToNow")
}

// MARK: - Preview
#Preview {
    let container = try! ModelContainer(
        for: QuadrantTask.self, DailyTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return DailyView()
        .modelContainer(container)
}

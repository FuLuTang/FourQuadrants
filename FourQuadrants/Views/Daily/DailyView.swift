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
        VStack(spacing: 0) {
            // 1. 日期导航栏
            dateHeader
            
            // 2. 时间轴滚动区域
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
                    .padding(.bottom, 80) // 底部留白给 FAB
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToCurrentTime()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // 右下角添加按钮
            Button {
                showAddTaskSheet = true // Present Sheet
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 4, y: 3)
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
                    .foregroundColor(.blue)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
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
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .padding()
            }
            
            Spacer()
            
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .onTapGesture {
                    // TODO: 弹出小日历
                    withAnimation {
                        selectedDate = Date()
                    }
                }
            
            Spacer()
            
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .padding()
            }
        }
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
        .zIndex(1)
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
            let date = context.date
            if Calendar.current.isDateInToday(date) {
                let calendar = Calendar.current
                let hour = CGFloat(calendar.component(.hour, from: date))
                let minute = CGFloat(calendar.component(.minute, from: date))
                let totalMinutes = hour * 60 + minute
                let yOffset = (totalMinutes / 60) * hourHeight + 10 // +10 top padding match grid
                
                HStack(spacing: 0) {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                        .frame(width: timeColumnWidth, alignment: .trailing)
                        .padding(.trailing, 4)
                        .background(Color(UIColor.systemBackground)) // 遮挡背景网格
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 1)
                }
                .offset(y: yOffset)
            }
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
        withAnimation(.spring()) {
            task.startTime = newStartDate
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let scrollDailyToNow = Notification.Name("scrollDailyToNow")
}

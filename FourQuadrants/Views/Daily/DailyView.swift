import SwiftUI
import SwiftData
import Combine

struct DailyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate: Date = Date()
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showAddTaskSheet = false // Add Sheet State
    @State private var headerDragOffset: CGFloat = 0 // Date Header Swipe State
    @State private var transitionEdge: Edge = .trailing // Transition Direction State
    @State private var editingTaskId: PersistentIdentifier? // Global Edit State
    // New Task Interaction State
    @State private var ghostTask: DailyTask? // Transient task during creation/drag
    @State private var isGhostDragging = false
    @State private var showGhostForm = false
    @State private var lastHapticOffset: CGFloat = 0 // Track for haptic mapping
    @State private var headerWidth: CGFloat = 0 // Track physical width for haptic mapping
    
    // New Gesture States - REMOVED (Replaced by UIKit)
    
    // MARK: - 常量
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
                    // 1. 背景网格 (作为手势的载体)

                    timeGrid
                        // ❌ 删除原来的 .gesture/simultaneousGesture
                        // ✅ 添加新的 UIKit 手势层
                        .overlay(
                            TimeGridGesture(
                                minDuration: 0.5,
                                onBegan: { point in
                                    // 长按触发：立即在当前坐标创建 Ghost
                                    createGhostTask(at: point.y)
                                },
                                onChanged: { point in
                                    // 手指不松开，继续移动：更新 Ghost 位置
                                    if let ghost = ghostTask {
                                        updateGhostPosition(ghost, at: point.y)
                                    }
                                },
                                onEnded: { point in
                                    // 松手：确认创建
                                    if let ghost = ghostTask {
                                        commitGhostTask(ghost)
                                    }
                                }
                            )
                        )
                        .contentShape(Rectangle()) // 确保空白处也能点击
                        // 2. 只有点击交互 (点击空白取消编辑)
                        .onTapGesture {
                            withAnimation {
                                editingTaskId = nil
                            }
                        }
                    
                    // 任务块 (这里需要查询当天的任务)
                    DailyTasksLayer(
                        selectedDate: selectedDate,
                        hourHeight: hourHeight,
                        timeColumnWidth: timeColumnWidth,
                        editingTaskId: $editingTaskId
                    )
                    
                    // Ghost Task Layer (Transient)
                    if let ghost = ghostTask, !showGhostForm {
                        DailyTaskBlock(task: ghost, hourHeight: hourHeight, editingTaskId: .constant(nil))
                            .frame(maxWidth: .infinity)
                            .padding(.leading, timeColumnWidth + 8)
                            .padding(.trailing, 8)
                            .frame(height: (CGFloat(ghost.duration) / 3600.0) * hourHeight)
                            .offset(y: calculateYOffset(for: ghost))
                            .opacity(0.8) // Ghostly appearance
                            .allowsHitTesting(false)
                    }
                    
                    // 当前时间红线 (只在今天显示)
                    if Calendar.current.isDateInToday(selectedDate) {
                        CurrentTimeLine(hourHeight: hourHeight, timeColumnWidth: timeColumnWidth)
                    }
                }
                .coordinateSpace(name: "DailyZStack")
                .frame(height: CGFloat(endHour - startHour) * hourHeight + 20) // +20 padding
                // .padding(.top, 60) removed to allow content behind heater
                .padding(.bottom, 80) // 底部留白给 FAB
            }
            .contentMargins(.top, 80, for: .scrollContent) // Allow scrolling under header
            .onAppear {
                scrollProxy = proxy
                scrollToCurrentTime()
            }
        }
        .scrollDisabled(editingTaskId != nil || isGhostDragging) // Disable scroll when editing or creating
        // Actually, if we put the gesture on the ZStack background, it might block scrolling if not careful.
        // The `Color.clear` above is inside ScrollView.
        
        // Stronger Top Fade
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(UIColor.systemBackground), Color(UIColor.systemBackground).opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 100)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        // 日期导航栏（浮动在顶部）
        .overlay(alignment: .top) {
            dateHeader
        }
        .overlay(alignment: .bottomTrailing) {
            // 右下角添加按钮
            Button {
                let now = Date()
                let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
                let rounded = Calendar.current.date(bySetting: .minute, value: 0, of: nextHour)!
                
                // Create a "Draft" task for the sheet
                let draft = DailyTask(
                    title: "",
                    scheduledDate: selectedDate,
                    startTime: rounded,
                    duration: 3600,
                    colorHex: "#5E81F4"
                )
                self.ghostTask = draft
                self.showGhostForm = true
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
        .sheet(isPresented: $showGhostForm, onDismiss: {
            // Handle cancellation (if task wasn't saved)
            // But we don't need to do anything specifically, resetGhostTask will happen
            resetGhostTask()
        }) {
            if let task = ghostTask {
                DailyTaskFormView(task: task, selectedDate: selectedDate, isNew: true) { savedTask in
                    // Callback when saved (inserted)
                    modelContext.insert(savedTask)
                    try? modelContext.save()
                    // Immediately enter edit mode or just finish?
                    // User said: "松手后会自动弹出来编辑页" -> which is this sheet.
                }
            } else {
                // Fallback
                DailyTaskFormView(selectedDate: selectedDate)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // 左下角“回到当前”按钮
            Button {
                let now = Date()
                // Only update selectedDate if not today to avoid header transition
                if !Calendar.current.isDate(selectedDate, inSameDayAs: now) {
                    withAnimation {
                        selectedDate = now
                    }
                }
                // Always scroll to time
                withAnimation {
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
        // Native Haptics: Trigger on date change
        .sensoryFeedback(.selection, trigger: selectedDate)
    }
    
    // MARK: - 组件
    
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
                    .frame(minWidth: 120)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .offset(x: headerDragOffset)
                    .opacity(1.0 - abs(headerDragOffset) / 150.0)
                    .id(selectedDate) // Transition ID
                    .transition(.push(from: transitionEdge))
                // --- 核心滑动逻辑 ---
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                headerDragOffset = value.translation.width
                                
                                // --- Haptic Distance-Intensity-Density Mapping ---
                                let currentX = value.translation.width
                                let absX = abs(currentX)
                                let halfWidth = max(50, headerWidth / 2)
                                
                                // Finger outside the physical slider block
                                guard absX <= halfWidth else { return }
                                
                                // 1. Density Mapping (Gap: 35px -> 2px)
                                let dynamicGap = max(2, 35.0 - (absX / halfWidth) * 33.0)
                                
                                // 2. Intensity Mapping (Strength: 0.3 -> 1.0)
                                let intensity = 0.3 + (absX / halfWidth) * 0.7
                                
                                if abs(currentX - lastHapticOffset) > dynamicGap {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred(intensity: intensity)
                                    lastHapticOffset = currentX
                                }
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 40
                                if value.translation.width < -threshold {
                                    changeDate(by: 1) // 向左滑，看未来
                                } else if value.translation.width > threshold {
                                    changeDate(by: -1) // 向右滑，回过去
                                } else {
                                    withAnimation(.spring()) {
                                        headerDragOffset = 0
                                    }
                                }
                                lastHapticOffset = 0 // Reset for next swipe
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
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            headerWidth = geo.size.width
                        }
                        .onChange(of: geo.size.width) { _, newValue in
                            headerWidth = newValue
                        }
                }
            )
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
        transitionEdge = days > 0 ? .trailing : .leading
        // 使用 iOS 26 推荐的物理弹簧动画，模拟“推挤”玻璃的感觉
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
            headerDragOffset = 0 // Reset swipe offset
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
    
    // MARK: - Ghost Task Logic
    
    private func createGhostTask(at yOffset: CGFloat) {
        let (hour, minute) = timeFromY(yOffset)
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard let startTime = calendar.date(from: components) else { return }
        
        ghostTask = DailyTask(
            title: String(localized: "new_task"),
            scheduledDate: selectedDate,
            startTime: startTime,
            duration: 3600,
            colorHex: "#5E81F4"
        )
        isGhostDragging = true
        
        // Haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }
    
    private func updateGhostPosition(_ task: DailyTask, at yOffset: CGFloat) {
         let (hour, minute) = timeFromY(yOffset)
         
         let calendar = Calendar.current
         var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
         components.hour = hour
         components.minute = minute
         components.second = 0
         
         guard let startTime = calendar.date(from: components) else { return }
         
         if task.startTime != startTime {
             let feedback = UISelectionFeedbackGenerator()
             feedback.selectionChanged()
             task.startTime = startTime
         }
    }
    
    private func commitGhostTask(_ task: DailyTask) {
        showGhostForm = true
        isGhostDragging = false
    }
    
    private func resetGhostTask() {
        ghostTask = nil
        isGhostDragging = false
        showGhostForm = false
    }
    
    // Helper to extract time from Y offset (reused by updateGhostTask)
    private func timeFromY(_ yOffset: CGFloat) -> (Int, Int) {
        let totalHours = Double((yOffset - 10) / hourHeight)
        let hour = Int(totalHours)
        let minute = Int((totalHours - Double(hour)) * 60)
        
        let clampedHour = max(0, min(23, hour))
        let clampedMinute = (minute / 15) * 15 // Snap to 15m
        return (clampedHour, clampedMinute)
    }
    
    // Modified to use the new calculation if needed, but keeping the old one for offsets
    private func calculateYOffset(for task: DailyTask) -> CGFloat {
        let calendar = Calendar.current
        let hour = CGFloat(calendar.component(.hour, from: task.startTime))
        let minute = CGFloat(calendar.component(.minute, from: task.startTime))
        return ((hour * 60 + minute) / 60) * hourHeight + 10
    }
    
    // MARK: - 子视图
    
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
        @Binding var editingTaskId: PersistentIdentifier?
        
        @Query private var tasks: [DailyTask]
        
        init(selectedDate: Date, hourHeight: CGFloat, timeColumnWidth: CGFloat, editingTaskId: Binding<PersistentIdentifier?>) {
            self.selectedDate = selectedDate
            self.hourHeight = hourHeight
            self.timeColumnWidth = timeColumnWidth
            self._editingTaskId = editingTaskId
            
            // 构造谓词查询当天的任务
            let startOfDay = Calendar.current.startOfDay(for: selectedDate)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            
            self._tasks = Query(filter: #Predicate<DailyTask> { task in
                task.scheduledDate >= startOfDay && task.scheduledDate < endOfDay
            }, sort: \.startTime)
        }
        
        var body: some View {
            // Calculate layout once when tasks change
            let layout = DailyTaskLayout.calculateLayout(for: tasks, hourHeight: hourHeight)
            let screenWidth = UIScreen.main.bounds.width
            let availableWidth = screenWidth - timeColumnWidth - 24
            
            return ZStack(alignment: .topLeading) {
                ForEach(tasks) { task in
                    if let geometry = layout[task.id] {
                        
                        // Calculate precise frame and position
                        let width = availableWidth * geometry.frame.width
                        let height = geometry.frame.height
                        
                        // X position is left padding + offset + half width (because position is center)
                        let xOffset = timeColumnWidth + 8 + (geometry.frame.origin.x * availableWidth)
                        let xPosition = xOffset + (width / 2)
                        
                        // Y position is top padding + offset + half height
                        let yPosition = geometry.frame.origin.y + (height / 2)
                        
                        DailyTaskBlock(task: task, hourHeight: hourHeight, editingTaskId: $editingTaskId)
                            .frame(width: width, height: height)
                            .position(x: xPosition, y: yPosition)
                    }
                }
            }
            // Ensure container has enough height
            .frame(height: CGFloat(24) * hourHeight + 20)
        }
    }
}

// MARK: - 通知模块
extension Notification.Name {
    static let scrollDailyToNow = Notification.Name("scrollDailyToNow")
}

// MARK: - 预览
#Preview {
    let container = try! ModelContainer(
        for: QuadrantTask.self, DailyTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return DailyView()
        .modelContainer(container)
}

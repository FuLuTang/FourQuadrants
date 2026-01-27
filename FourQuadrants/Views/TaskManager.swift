import SwiftUI
import Combine

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    
    init() {
        // 添加默认任务
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd"
        
        tasks.append(Task(title: "重要且紧急任务", date: dateFormatter.date(from: "2023.01.01")!, isCompleted: false, importance: .high, isUrgent: true))
        tasks.append(Task(title: "重要不紧急任务", date: dateFormatter.date(from: "2023.06.01")!, targetDate: dateFormatter.date(from: "2025.01.02")!, isCompleted: false, importance: .high, isUrgent: false))
        tasks.append(Task(title: "紧急不重要任务", date: dateFormatter.date(from: "2024.01.01")!, targetDate: dateFormatter.date(from: "2025.03.02")!, isCompleted: false, importance: .normal, isUrgent: true))
        tasks.append(Task(title: "不重要不紧急任务", date: dateFormatter.date(from: "2024.06.01")!, isCompleted: false, isUrgent: false))
        tasks.append(Task(title: "额外任务", date: dateFormatter.date(from: "2025.01.01")!, isCompleted: false, isUrgent: false))
        //预设：目标日期为当天日期+1和-1的两个任务
        tasks.append(Task(title: "安装日期+1", date: Date(), targetDate: Date().addingTimeInterval(86400), isCompleted: false, isUrgent: false))    
        tasks.append(Task(title: "安装日期-1", date: Date(), targetDate: Date().addingTimeInterval(-86400), isCompleted: false, isUrgent: false))
        //预设：置顶任务
        tasks.append(Task(title: "置顶", date: Date(), targetDate: Date().addingTimeInterval(-86400), isCompleted: false, isUrgent: false, isTop: true))
        //预设：完成日期为当天日期和-1的两个任务
        tasks.append(Task(title: "完成日期", date: Date(), isCompleted: true, importance: .high, isUrgent: true, completionDate: Date()))
        tasks.append(Task(title: "完成日期-1", date: Date(), isCompleted: true, importance: .high, isUrgent: true, completionDate: Date().addingTimeInterval(-86400)))
        //排序测试
        tasks.append(Task(title: "排序测试5", date: Date().addingTimeInterval(-10000), targetDate: Date().addingTimeInterval(86400), isCompleted: false, isUrgent: true)) // 创建日期最早，目标日期最近
        tasks.append(Task(title: "排序测试6", date: Date().addingTimeInterval(-5000), targetDate: Date().addingTimeInterval(172800), isCompleted: false, isUrgent: true)) // 创建日期较早，目标日期较晚
        tasks.append(Task(title: "排序测试4", date: Date().addingTimeInterval(-3000), targetDate: Date().addingTimeInterval(-86400), isCompleted: false, isUrgent: true)) // 创建日期较晚，目标日期较早
        tasks.append(Task(title: "排序测试7", date: Date().addingTimeInterval(-8000), targetDate: Date().addingTimeInterval(432000), isCompleted: false, isUrgent: true)) // 创建日期较早，目标日期很远
        tasks.append(Task(title: "排序测试8", date: Date().addingTimeInterval(2000), targetDate: Date().addingTimeInterval(864000), isCompleted: false, isUrgent: true)) // 创建日期最晚，目标日期最远
        tasks.append(Task(title: "排序测试2（置顶）", date: Date().addingTimeInterval(-4000), targetDate: Date().addingTimeInterval(86400*5), isCompleted: false, isUrgent: true, isTop: true)) // 置顶任务，创建日期较早
        tasks.append(Task(title: "排序测试3（置顶）", date: Date().addingTimeInterval(-1000), isCompleted: false, isUrgent: true, isTop: true)) // 置顶任务，创建日期较晚
        tasks.append(Task(title: "排序测试1（置顶）", date: Date().addingTimeInterval(3000), targetDate: Date().addingTimeInterval(86400*2), isCompleted: false, isUrgent: true, isTop: true)) // 置顶任务，目标日期早

    }

    func addTask(title: String, importance: ImportanceLevel, isUrgent: Bool, isTop: Bool, targetDate: Date? = nil, urgentThresholdDays: Int? = nil, dateLatestModified: Date) {
        var newTask = Task(
            title: title,
            date: Date(),
            dateLatestModified: Date(), // 任务创建时间
            targetDate: targetDate,
            isCompleted: false,
            importance: importance,
            isUrgent: isUrgent,
            urgentThresholdDays: urgentThresholdDays,
            isTop: isTop
        )
        newTask.updateUrgency()
        tasks.append(newTask)
    }

    func updateTask(_ task: Task, title: String, importance: ImportanceLevel, isUrgent: Bool, isTop: Bool, targetDate: Date?, urgentThresholdDays: Int? = nil, dateLatestModified: Date) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].title = title
            tasks[index].importance = importance
            tasks[index].isUrgent = isUrgent
            tasks[index].targetDate = targetDate
            tasks[index].urgentThresholdDays = urgentThresholdDays
            tasks[index].isTop = isTop
            tasks[index].updateUrgency()
            tasks[index].dateLatestModified = Date() // 更新最后修改时间
            objectWillChange.send()
        }
    }

    
    func toggleTask(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.easeInOut) {
            tasks[index].isCompleted.toggle()
            tasks[index].completionDate = tasks[index].isCompleted ? Date() : nil
            objectWillChange.send()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut) {
                self.objectWillChange.send()
            }
        }
    }

    func removeTask(by id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    // 任务排序法
    enum TaskSortMethod {
        case intelligence   // 现置顶 -> 目标日 -> 创建日
        case byTargetDate   // 仅按目标日排序
        case byCreationDate // 仅按创建日期排序
        case byName
    }
    func sortTasks(_ tasks: [Task], by method: TaskSortMethod) -> [Task] {
        return tasks.sorted { task1, task2 in
            switch method {
            case .intelligence:
                // 1. 置顶任务优先
                if task1.isTop != task2.isTop {
                    return task1.isTop && !task2.isTop
                }
                // 2. 目标日期优先
                if let date1 = task1.targetDate, let date2 = task2.targetDate {
                    return date1 < date2
                } else if task1.targetDate != nil {
                    return true
                } else if task2.targetDate != nil {
                    return false
                }
                // 3. 按重要度排序（high > normal > low）
                let importanceOrder: [ImportanceLevel] = [.high, .normal, .low]
                if let index1 = importanceOrder.firstIndex(of: task1.importance),
                   let index2 = importanceOrder.firstIndex(of: task2.importance) {
                    return index1 < index2
                }
                // 4. 修改日期排序（较早创建的任务排前）
                return task1.dateLatestModified < task2.dateLatestModified

            case .byTargetDate:
                return (task1.targetDate ?? .distantFuture) < (task2.targetDate ?? .distantFuture)

            case .byCreationDate:
                return task1.date < task2.date
            
            case .byName:
                return task1.title < task2.title
            }
        }
    }

    func dragTaskChangeCategory(task: Task, targetCategory: TaskCategory) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        // **更新重要性**：重要象限设为 high，其它设为 normal
        switch targetCategory {
        case .importantAndUrgent, .importantButNotUrgent:
            tasks[index].importance = .high
        case .urgentButNotImportant, .notImportantAndNotUrgent:
            tasks[index].importance = .normal
        default:
            break
        }
        // **更新紧急性**
        let expectsUrgent: Bool = {
            switch targetCategory {
            case .importantAndUrgent, .urgentButNotImportant:
                return true
            case .importantButNotUrgent, .notImportantAndNotUrgent:
                return false
            default:
                return tasks[index].isUrgent
            }
        }()
        
        if expectsUrgent {
            if let targetDate = tasks[index].targetDate {
                // 计算目标日期与当前日期的差值（天）
                let now = Date()
                let diff = Calendar.current.dateComponents([.day], from: now, to: targetDate).day ?? 0
                tasks[index].urgentThresholdDays = diff
                tasks[index].isUrgent = (diff >= 0) // diff >= 0 则设为紧急
            } else {
                tasks[index].isUrgent = true
            }
        } else {
            // 从紧急降为不紧急时清除紧急阈值
            tasks[index].urgentThresholdDays = nil
            tasks[index].isUrgent = false
        }
        // **更新最后编辑日期**
        tasks[index].dateLatestModified = Date()
        objectWillChange.send()
    }

}

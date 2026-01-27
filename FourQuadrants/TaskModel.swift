import Foundation

enum ImportanceLevel: String {
    case low, normal, high
}

struct Task: Identifiable {
    var id = UUID()
    var title: String
    var date: Date
    var dateLatestModified: Date = Date()
    var targetDate: Date? = nil
    var isCompleted: Bool = false
    var importance: ImportanceLevel = .normal  // 替换 isImportant
    var isUrgent: Bool = false
    var urgentThresholdDays: Int? = nil
    var completionDate: Date?
    var isTop: Bool = false
    
    var isOverdue: Bool {// 有目标日期：用 date的后一天 和 targetDate 判断。无目标日期：默认不逾期
        guard !isCompleted else { return false }
        return targetDate.map { $0.advanced(by: 86400) } ?? date < Date()
    }
    
    // **自动更新紧急状态函数**
    mutating func updateUrgency() {
        if let threshold = urgentThresholdDays, let target = targetDate {
            let now = Calendar.current.startOfDay(for: Date())
            let targetDay = Calendar.current.startOfDay(for: target)
            let daysRemaining = Calendar.current.dateComponents([.day], from: now, to: targetDay).day ?? Int.max
            isUrgent = daysRemaining <= threshold
        }
    }
}


import Foundation
import SwiftData

/// Opt-in in-memory fixtures for visual acceptance. Never configures SyncService.
@MainActor
enum MacPreviewData {
    static func populate(_ context: ModelContext) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let samples: [(String, ImportanceLevel, Bool, Int?, String)] = [
            ("提交产品设计方案", .high, true, 0, "确认主窗口与桌面便笺的使用体验。\n检查任务的完成、编辑与撤销路径。"),
            ("回复合作伙伴邮件", .high, true, 0, "整理反馈，并约定下次讨论时间。"),
            ("整理本周项目进度", .high, true, -1, "回顾本周已完成的工作。"),
            ("设计 macOS 工作空间", .high, false, 4, "用键盘、鼠标和多窗口提高日常效率。"),
            ("阅读与学习计划", .high, false, 7, "每天留一点时间给长期目标。"),
            ("准备下月旅行", .high, false, nil, "记录路线与想去的地方。"),
            ("确认明天的会议时间", .normal, true, 1, ""),
            ("领取快递", .normal, true, 0, ""),
            ("整理桌面文件", .normal, false, nil, ""),
            ("看看收藏的文章", .low, false, nil, "")
        ]
        var tasks: [QuadrantTask] = []
        for (index, sample) in samples.enumerated() {
            let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!
            let task = QuadrantTask(id: id, title: sample.0, notes: sample.4,
                dueAt: sample.3.flatMap { calendar.date(byAdding: .day, value: $0, to: today) },
                importance: sample.1, isUrgent: sample.2, isTop: index == 0)
            context.insert(task)
            tasks.append(task)
        }
        let finished = QuadrantTask(id: UUID(uuidString: "00000000-0000-4000-8000-000000000011")!, title: "完成第一轮需求讨论", importance: .high)
        finished.completedAt = today.addingTimeInterval(-3600)
        context.insert(finished)
        let blocks: [(String, Int, Int, String, Int?)] = [
            ("梳理今日任务", 9 * 60, 30, "#65A98D", nil),
            ("产品设计时间", 10 * 60, 90, "#5E8DCA", 3),
            ("方案评审", 11 * 60, 45, "#D9A052", 0),
            ("处理邮件", 14 * 60, 45, "#B18BC4", 1),
            ("阅读与复盘", 16 * 60, 60, "#65A98D", 4)
        ]
        for block in blocks {
            let item = DailyTask(title: block.0, startAt: today.addingTimeInterval(Double(block.1 * 60)),
                duration: Double(block.2 * 60), colorHex: block.3,
                notes: "为这段时间保留专注的空间。", quadrantTask: block.4.map { tasks[$0] })
            context.insert(item)
        }
        try context.save()
    }
}

import Foundation
import SwiftData
#if os(iOS)
import WidgetKit
#endif

private struct WidgetSnapshot: Codable {
    struct Task: Codable {
        let id: String
        let title: String
        let dueLabel: String
        let quadrant: String
        let colorHex: String
        let isOverdue: Bool
        let hasDueDate: Bool
        let dueDate: Date?
    }

    struct Quadrant: Codable {
        let key: String
        let title: String
        let count: Int
        let colorHex: String
        let tasks: [Task]
    }

    let generatedAt: Date
    let openCount: Int
    let focusTask: Task?
    let recommendedTasks: [Task]
    let quadrants: [Quadrant]
}

enum WidgetSnapshotService {
    private static let filename = "widget-snapshot.json"
    private static let appGroup: String = {
        #if DEBUG
        "group.fulu.FourQuadrants.dev"
        #else
        "group.fulu.FourQuadrants"
        #endif
    }()

    @MainActor
    static func write(context: ModelContext) {
        #if os(iOS)
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return }
        let tasks = (try? context.fetch(FetchDescriptor<QuadrantTask>())) ?? []
        let openTasks = tasks.filter { !$0.isCompleted }
        let sorted = TaskOrdering.recommended(openTasks, limit: 5)
        let counts = Dictionary(grouping: openTasks, by: { $0.category }).mapValues(\.count)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        func taskSnapshot(_ task: QuadrantTask) -> WidgetSnapshot.Task {
            WidgetSnapshot.Task(
                id: task.id.uuidString,
                title: task.title,
                dueLabel: task.displayDueDate.map { formatter.string(from: $0) } ?? String(localized: "widget_no_due_date"),
                quadrant: task.category.rawValue,
                colorHex: color(for: task.category),
                isOverdue: task.isOverdue,
                hasDueDate: task.displayDueDate != nil,
                dueDate: task.displayDueDate
            )
        }

        let quadrants = [
            makeQuadrant(.importantAndUrgent, title: "category_important_urgent", tasks: openTasks, counts: counts, transform: taskSnapshot),
            makeQuadrant(.importantButNotUrgent, title: "category_important_not_urgent", tasks: openTasks, counts: counts, transform: taskSnapshot),
            makeQuadrant(.urgentButNotImportant, title: "category_urgent_not_important", tasks: openTasks, counts: counts, transform: taskSnapshot),
            makeQuadrant(.notImportantAndNotUrgent, title: "category_not_important_not_urgent", tasks: openTasks, counts: counts, transform: taskSnapshot)
        ]
        let recommendedTasks = sorted.map(taskSnapshot)
        let snapshot = WidgetSnapshot(
            generatedAt: .now,
            openCount: openTasks.count,
            focusTask: recommendedTasks.first,
            recommendedTasks: recommendedTasks,
            quadrants: quadrants
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        WidgetCenter.shared.reloadTimelines(ofKind: "FourQuadrantsWidget")
        #endif
    }

    static func sortTasksForWidget(_ tasks: [QuadrantTask]) -> [QuadrantTask] {
        TaskOrdering.sorted(tasks, by: .intelligence)
    }

    private static func makeQuadrant(
        _ category: TaskCategory,
        title: String,
        tasks: [QuadrantTask],
        counts: [TaskCategory: Int],
        transform: (QuadrantTask) -> WidgetSnapshot.Task
    ) -> WidgetSnapshot.Quadrant {
        let categoryTasks = TaskOrdering.sorted(tasks.filter { $0.category == category }, by: .intelligence).prefix(5).map(transform)
        return WidgetSnapshot.Quadrant(
            key: category.rawValue,
            title: String(localized: String.LocalizationValue(title)),
            count: counts[category] ?? 0,
            colorHex: color(for: category),
            tasks: Array(categoryTasks)
        )
    }

    private static func color(for category: TaskCategory) -> String {
        switch category {
        case .importantAndUrgent: "#FF334D"
        case .importantButNotUrgent: "#3380FF"
        case .urgentButNotImportant: "#00E680"
        default: "#B3B3CC"
        }
    }
}

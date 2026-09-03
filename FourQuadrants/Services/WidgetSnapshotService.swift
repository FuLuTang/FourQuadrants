import Foundation
import SwiftData
import WidgetKit

private struct WidgetSnapshot: Codable {
    struct Task: Codable { let title: String; let dueLabel: String; let quadrant: String; let colorHex: String }
    struct Quadrant: Codable { let title: String; let count: Int; let colorHex: String }
    let generatedAt: Date
    let openCount: Int
    let focusTask: Task?
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
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return }
        let tasks = (try? context.fetch(FetchDescriptor<QuadrantTask>())) ?? []
        let openTasks = tasks.filter { !$0.isCompleted }
        let sorted = openTasks.sorted { lhs, rhs in
            (lhs.effectiveDueDateKey ?? "9999-12-31", lhs.createdAt) < (rhs.effectiveDueDateKey ?? "9999-12-31", rhs.createdAt)
        }
        let counts = Dictionary(grouping: openTasks, by: { $0.category }).mapValues(\.count)
        let quadrants = [
            WidgetSnapshot.Quadrant(title: "Important & urgent", count: counts[.importantAndUrgent] ?? 0, colorHex: "#E34B4B"),
            WidgetSnapshot.Quadrant(title: "Important", count: counts[.importantButNotUrgent] ?? 0, colorHex: "#3D9BE9"),
            WidgetSnapshot.Quadrant(title: "Urgent", count: counts[.urgentButNotImportant] ?? 0, colorHex: "#4CAF72"),
            WidgetSnapshot.Quadrant(title: "Other", count: counts[.notImportantAndNotUrgent] ?? 0, colorHex: "#8E8E93")
        ]
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let focus = sorted.first.map { task in
            WidgetSnapshot.Task(title: task.title, dueLabel: task.displayDueDate.map { formatter.string(from: $0) } ?? "No due date", quadrant: task.category.rawValue, colorHex: color(for: task.category))
        }
        let snapshot = WidgetSnapshot(generatedAt: .now, openCount: openTasks.count, focusTask: focus, quadrants: quadrants)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        WidgetCenter.shared.reloadTimelines(ofKind: "FourQuadrantsWidget")
    }

    private static func color(for category: TaskCategory) -> String {
        switch category {
        case .importantAndUrgent: "#E34B4B"
        case .importantButNotUrgent: "#3D9BE9"
        case .urgentButNotImportant: "#4CAF72"
        default: "#8E8E93"
        }
    }
}

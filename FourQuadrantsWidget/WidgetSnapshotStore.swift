import Foundation
import SwiftUI

struct WidgetSnapshot: Codable {
    struct Task: Codable, Identifiable {
        let id: String
        let title: String
        let dueLabel: String
        let quadrant: String
        let colorHex: String
        let isOverdue: Bool
        var hasDueDate: Bool? = nil
        var dueDate: Date? = nil
    }

    struct Quadrant: Codable, Identifiable {
        let key: String
        let title: String
        let count: Int
        let colorHex: String
        let tasks: [Task]

        var id: String { key }
        var color: Color { Color(hex: colorHex) }
    }

    let generatedAt: Date
    let openCount: Int
    let focusTask: Task?
    let recommendedTasks: [Task]
    let quadrants: [Quadrant]

    private enum CodingKeys: String, CodingKey {
        case generatedAt, openCount, focusTask, recommendedTasks, quadrants
    }

    init(generatedAt: Date, openCount: Int, focusTask: Task?, recommendedTasks: [Task], quadrants: [Quadrant]) {
        self.generatedAt = generatedAt
        self.openCount = openCount
        self.recommendedTasks = recommendedTasks.isEmpty ? focusTask.map { [$0] } ?? [] : recommendedTasks
        self.focusTask = self.recommendedTasks.first
        self.quadrants = quadrants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        openCount = try container.decode(Int.self, forKey: .openCount)
        quadrants = try container.decode([Quadrant].self, forKey: .quadrants)

        let legacyFocusTask = try container.decodeIfPresent(Task.self, forKey: .focusTask)
        if let decodedRecommendedTasks = try container.decodeIfPresent([Task].self, forKey: .recommendedTasks) {
            recommendedTasks = decodedRecommendedTasks
            focusTask = decodedRecommendedTasks.first
        } else {
            recommendedTasks = legacyFocusTask.map { [$0] } ?? []
            focusTask = legacyFocusTask
        }
    }

    func task(for id: String) -> Task? {
        quadrants.flatMap(\.tasks).first { $0.id == id }
    }

    static let sample = WidgetSnapshot(
        generatedAt: .now,
        openCount: 5,
        focusTask: Task(id: "sample-1", title: "Prepare project review", dueLabel: "Today", quadrant: "important_urgent", colorHex: "#FF334D", isOverdue: false, hasDueDate: true, dueDate: .now),
        recommendedTasks: [
            Task(id: "sample-1", title: "Prepare project review", dueLabel: "Today", quadrant: "important_urgent", colorHex: "#FF334D", isOverdue: false, hasDueDate: true, dueDate: .now),
            Task(id: "sample-2", title: "Send the proposal", dueLabel: "Yesterday", quadrant: "important_urgent", colorHex: "#FF334D", isOverdue: true, hasDueDate: true, dueDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)),
            Task(id: "sample-4", title: "Book a room", dueLabel: "Tomorrow", quadrant: "urgent_not_important", colorHex: "#00E680", isOverdue: false, hasDueDate: true, dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)),
            Task(id: "sample-3", title: "Plan next quarter", dueLabel: "In three days", quadrant: "important_not_urgent", colorHex: "#3380FF", isOverdue: false, hasDueDate: true, dueDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)),
            Task(id: "sample-5", title: "Sort reading list", dueLabel: "No due date", quadrant: "not_important_not_urgent", colorHex: "#B3B3CC", isOverdue: false)
        ],
        quadrants: [
            Quadrant(key: "important_urgent", title: "Important & urgent", count: 2, colorHex: "#FF334D", tasks: [
                Task(id: "sample-1", title: "Prepare project review", dueLabel: "Today", quadrant: "important_urgent", colorHex: "#FF334D", isOverdue: false, hasDueDate: true, dueDate: .now),
                Task(id: "sample-2", title: "Send the proposal", dueLabel: "Tomorrow", quadrant: "important_urgent", colorHex: "#FF334D", isOverdue: false, hasDueDate: true, dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now))
            ]),
            Quadrant(key: "important_not_urgent", title: "Important", count: 1, colorHex: "#3380FF", tasks: [
                Task(id: "sample-3", title: "Plan next quarter", dueLabel: "In three days", quadrant: "important_not_urgent", colorHex: "#3380FF", isOverdue: false, hasDueDate: true, dueDate: Calendar.current.date(byAdding: .day, value: 3, to: .now))
            ]),
            Quadrant(key: "urgent_not_important", title: "Urgent", count: 1, colorHex: "#00E680", tasks: [
                Task(id: "sample-4", title: "Book a room", dueLabel: "Tomorrow", quadrant: "urgent_not_important", colorHex: "#00E680", isOverdue: false, hasDueDate: true, dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now))
            ]),
            Quadrant(key: "not_important_not_urgent", title: "Other", count: 1, colorHex: "#B3B3CC", tasks: [
                Task(id: "sample-5", title: "Sort reading list", dueLabel: "No due date", quadrant: "not_important_not_urgent", colorHex: "#B3B3CC", isOverdue: false)
            ])
        ]
    )
}

enum WidgetSnapshotStore {
    private static let filename = "widget-snapshot.json"
    private static let appGroup: String = {
        #if DEBUG
        "group.fulu.FourQuadrants.dev"
        #else
        "group.fulu.FourQuadrants"
        #endif
    }()

    static func read() -> WidgetSnapshot {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup),
              let data = try? Data(contentsOf: directory.appendingPathComponent(filename)),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return .sample }
        return snapshot
    }
}

extension Color {
    init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(normalized, radix: 16) ?? 0x8E8E93
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }
}

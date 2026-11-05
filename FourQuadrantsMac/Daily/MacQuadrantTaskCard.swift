import SwiftUI

struct MacQuadrantTaskCard: View {
    let task: QuadrantTask
    let isLinked: Bool

    /// The quadrant by importance and urgency, regardless of completion.
    private var quadrant: TaskCategory {
        switch (task.isImportantQuadrant, task.isUrgent) {
        case (true, true): .importantAndUrgent
        case (true, false): .importantButNotUrgent
        case (false, true): .urgentButNotImportant
        case (false, false): .notImportantAndNotUrgent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(task.title).font(.callout.weight(.medium)).lineLimit(1)
                if task.isCompleted {
                    Text("已完成").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 7) {
                MacQuadrantHeading(category: quadrant, font: .caption)
                if let dueDate = task.displayDueDate {
                    Text("·")
                    Text("截止 \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if isLinked, let notes = task.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

import Foundation
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacDailyTaskSuggestionsTests {
    @Test func termsCoverChineseShinglesAndWords() {
        let terms = MacDailyTaskSuggestions.terms("周报 Weekly")
        #expect(terms.contains("周报"))
        #expect(terms.contains("we"))
        #expect(terms.contains("wee"))
        #expect(terms.contains("weekly"))
        #expect(MacDailyTaskSuggestions.terms("a").isEmpty)
    }

    @Test func emptyQueryHasNoSuggestions() {
        let tasks = [QuadrantTask(title: "完成周报", importance: .normal)]
        #expect(MacDailyTaskSuggestions.ranked(title: "", notes: " ", among: tasks).isEmpty)
    }

    @Test func rankingPrefersCloserMatchesAndOpenTasks() {
        let close = QuadrantTask(title: "完成周报", importance: .normal)
        let loose = QuadrantTask(title: "周报模板整理与归档", importance: .normal)
        let unrelated = QuadrantTask(title: "买牛奶", importance: .normal)
        let ranked = MacDailyTaskSuggestions.ranked(title: "完成周报", notes: "", among: [loose, unrelated, close])
        #expect(ranked.map(\.task.id) == [close.id, loose.id])
        #expect(ranked.first?.matches.contains("周报") == true)

        let done = QuadrantTask(title: "完成周报", importance: .normal)
        done.completedAt = .now
        let tied = MacDailyTaskSuggestions.ranked(title: "完成周报", notes: "", among: [done, close])
        #expect(tied.first?.task.id == close.id)
    }

    @Test func limitAndIndexReuse() {
        let tasks = (0..<5).map { QuadrantTask(title: "复习 SwiftData \($0)", importance: .normal) }
        let index = MacDailyTaskSuggestions.Index(tasks: tasks)
        #expect(MacDailyTaskSuggestions.ranked(title: "复习 swiftdata", notes: "", in: index, limit: 2).count == 2)
        #expect(MacDailyTaskSuggestions.ranked(title: "复习 swiftdata", notes: "", in: index).count == 5)
        #expect(index.stamp == MacDailyTaskSuggestions.stamp(of: tasks))
        tasks[0].updatedAt = .now.addingTimeInterval(10)
        #expect(index.stamp != MacDailyTaskSuggestions.stamp(of: tasks))
    }
}

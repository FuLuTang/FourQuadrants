import Foundation

/// Keyword matching between a daily task's text and existing quadrant tasks.
enum MacDailyTaskSuggestions {
    struct Suggestion: Identifiable {
        let task: QuadrantTask
        let matches: [String]
        let score: Double
        var id: UUID { task.id }
    }

    /// Identifies a task's searchable state, so callers can tell when an index is stale.
    struct Stamp: Equatable {
        let id: UUID
        let updatedAt: Date
    }

    /// Candidate tasks with their terms computed once, reused across queries.
    struct Index {
        struct Entry {
            let task: QuadrantTask
            let terms: Set<String>
        }

        let entries: [Entry]
        let stamp: [Stamp]

        init(tasks: [QuadrantTask]) {
            entries = tasks.map { Entry(task: $0, terms: MacDailyTaskSuggestions.terms($0.title + " " + ($0.notes ?? ""))) }
            stamp = MacDailyTaskSuggestions.stamp(of: tasks)
        }
    }

    static func stamp(of tasks: [QuadrantTask]) -> [Stamp] {
        tasks.map { Stamp(id: $0.id, updatedAt: $0.updatedAt) }
    }

    static func ranked(title: String, notes: String, among tasks: [QuadrantTask], limit: Int = .max) -> [Suggestion] {
        ranked(title: title, notes: notes, in: Index(tasks: tasks), limit: limit)
    }

    static func ranked(title: String, notes: String, in index: Index, limit: Int = .max) -> [Suggestion] {
        let sourceTerms = terms(title + " " + notes)
        guard !sourceTerms.isEmpty else { return [] }

        let ranked: [Suggestion] = index.entries.compactMap { entry in
            let shared = sourceTerms.intersection(entry.terms).sorted()
            guard !shared.isEmpty else { return nil }
            let unionCount = sourceTerms.union(entry.terms).count
            let score = Double(shared.count) / Double(max(unionCount, 1))
            return Suggestion(task: entry.task, matches: shared, score: score)
        }
        .sorted {
            if $0.score == $1.score {
                if $0.task.isCompleted != $1.task.isCompleted { return !$0.task.isCompleted }
                return $0.task.updatedAt > $1.task.updatedAt
            }
            return $0.score > $1.score
        }
        return Array(ranked.prefix(limit))
    }

    /// Two- and three-character shingles of the alphanumerics, plus whole words,
    /// so Chinese (no spaces) and space-separated text both match.
    static func terms(_ text: String) -> Set<String> {
        let scalars = text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let characters = Array(String(String.UnicodeScalarView(scalars)))
        guard characters.count > 1 else { return [] }

        var result = Set<String>()
        for width in 2...min(3, characters.count) {
            for start in 0...(characters.count - width) {
                result.insert(String(characters[start..<(start + width)]))
            }
        }
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 }
        result.formUnion(words)
        return result
    }
}

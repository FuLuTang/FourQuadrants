import Foundation

enum MacStickyPaper: String, CaseIterable, Codable, Identifiable {
    case yellow
    case blue
    case green
    case pink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yellow: "Yellow"
        case .blue: "Blue"
        case .green: "Green"
        case .pink: "Pink"
        }
    }

    static func `default`(for category: TaskCategory) -> MacStickyPaper {
        switch category {
        case .importantAndUrgent: .pink
        case .importantButNotUrgent: .blue
        case .urgentButNotImportant: .yellow
        case .notImportantAndNotUrgent: .green
        case .all, .completed: .yellow
        }
    }
}

enum MacStickySource: Codable, Equatable {
    case selectedTaskIDs([UUID])
    case category(TaskCategory)
    case combined
    case smart

    private enum CodingKeys: String, CodingKey { case kind, taskIDs, category }
    private enum Kind: String, Codable { case selectedTaskIDs, category, combined, smart }

    var title: String {
        switch self {
        case .selectedTaskIDs: "手选任务"
        case .category(let category): category.displayName
        case .combined: "四合一"
        case .smart: "智能排列"
        }
    }

    var displayTitle: String { title }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .selectedTaskIDs:
            self = .selectedTaskIDs(try container.decode([UUID].self, forKey: .taskIDs))
        case .category:
            self = .category(try container.decode(TaskCategory.self, forKey: .category))
        case .combined:
            self = .combined
        case .smart:
            self = .smart
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .selectedTaskIDs(let ids):
            try container.encode(Kind.selectedTaskIDs, forKey: .kind)
            try container.encode(ids, forKey: .taskIDs)
        case .category(let category):
            try container.encode(Kind.category, forKey: .kind)
            try container.encode(category, forKey: .category)
        case .combined:
            try container.encode(Kind.combined, forKey: .kind)
        case .smart:
            try container.encode(Kind.smart, forKey: .kind)
        }
    }

}

struct MacStickyWindowFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let initial = MacStickyWindowFrame(x: 180, y: 620, width: 195, height: 330)

    func collapsed(to height: Double) -> MacStickyWindowFrame {
        MacStickyWindowFrame(
            x: x,
            y: y + self.height - height,
            width: width,
            height: height
        )
    }
}

struct MacStickyConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var source: MacStickySource
    var paper: MacStickyPaper
    var frame: MacStickyWindowFrame
    var isCollapsed: Bool
    var isVisible: Bool
    var isFloating: Bool
    var opacity: Double
    var showDetails: Bool

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? source.displayTitle : title
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, source, paper, frame, isCollapsed, isVisible, isFloating, opacity, showDetails
    }

    init(
        id: UUID = UUID(),
        title: String,
        source: MacStickySource = .selectedTaskIDs([]),
        paper: MacStickyPaper = .yellow,
        frame: MacStickyWindowFrame = .initial,
        isCollapsed: Bool = false,
        isVisible: Bool = false,
        isFloating: Bool = false,
        opacity: Double = 0.94,
        showDetails: Bool = false
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.paper = paper
        self.frame = frame
        self.isCollapsed = isCollapsed
        self.isVisible = isVisible
        self.isFloating = isFloating
        self.opacity = min(max(opacity, 0.65), 1)
        self.showDetails = showDetails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        source = try container.decode(MacStickySource.self, forKey: .source)
        paper = try container.decode(MacStickyPaper.self, forKey: .paper)
        frame = try container.decode(MacStickyWindowFrame.self, forKey: .frame)
        isCollapsed = try container.decode(Bool.self, forKey: .isCollapsed)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        isFloating = try container.decode(Bool.self, forKey: .isFloating)
        opacity = try container.decode(Double.self, forKey: .opacity)
        showDetails = try container.decodeIfPresent(Bool.self, forKey: .showDetails) ?? false
    }
}

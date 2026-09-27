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
}

enum MacStickySource: Codable, Equatable {
    case selectedTaskIDs([UUID])
    case category(TaskCategory)

    private enum CodingKeys: String, CodingKey { case kind, taskIDs, category }
    private enum Kind: String, Codable { case selectedTaskIDs, category }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .selectedTaskIDs:
            self = .selectedTaskIDs(try container.decode([UUID].self, forKey: .taskIDs))
        case .category:
            self = .category(try container.decode(TaskCategory.self, forKey: .category))
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
        }
    }

}

struct MacStickyWindowFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let initial = MacStickyWindowFrame(x: 180, y: 620, width: 290, height: 330)
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

    init(
        id: UUID = UUID(),
        title: String,
        source: MacStickySource = .selectedTaskIDs([]),
        paper: MacStickyPaper = .yellow,
        frame: MacStickyWindowFrame = .initial,
        isCollapsed: Bool = false,
        isVisible: Bool = false,
        isFloating: Bool = false,
        opacity: Double = 0.94
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
    }
}

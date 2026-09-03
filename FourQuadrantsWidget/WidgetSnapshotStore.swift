import Foundation
import SwiftUI

struct WidgetSnapshot: Codable {
    struct Task: Codable {
        let title: String
        let dueLabel: String
        let quadrant: String
        let colorHex: String
        var color: Color { Color(hex: colorHex) }
    }

    struct Quadrant: Codable, Identifiable {
        var id: String { title }
        let title: String
        let count: Int
        let colorHex: String
        var color: Color { Color(hex: colorHex) }
    }

    let generatedAt: Date
    let openCount: Int
    let focusTask: Task?
    let quadrants: [Quadrant]

    static let sample = WidgetSnapshot(generatedAt: .now, openCount: 4,
        focusTask: Task(title: "Prepare project review", dueLabel: "Today", quadrant: "Important & urgent", colorHex: "#E34B4B"),
        quadrants: [
            Quadrant(title: "Important & urgent", count: 1, colorHex: "#E34B4B"),
            Quadrant(title: "Important", count: 2, colorHex: "#3D9BE9"),
            Quadrant(title: "Urgent", count: 1, colorHex: "#4CAF72"),
            Quadrant(title: "Other", count: 0, colorHex: "#8E8E93")
        ])
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

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0x8E8E93
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }
}

import SwiftUI

struct MacQuadrantHeading: View {
    let category: TaskCategory
    let font: Font

    var body: some View {
        Self.styledText(category: category, font: font)
    }

    static func styledText(category: TaskCategory, font: Font) -> Text {
        var title = AttributedString(category.displayName)
        title.font = font.weight(.regular)

        switch category {
        case .importantAndUrgent:
            let parts = category.displayName.split(separator: "&", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                setFont(font.weight(.bold), for: String(parts[0]), in: &title)
                setFont(font.weight(.bold), for: String(parts[1]), in: &title)
            } else {
                title.font = font.weight(.bold)
            }
        case .importantButNotUrgent, .urgentButNotImportant:
            title.font = font.weight(.bold)
        case .notImportantAndNotUrgent:
            let words = category.displayName.split(separator: "✗", omittingEmptySubsequences: true)
            for word in words {
                setStrikethrough(for: String(word), in: &title)
            }
        case .all, .completed:
            break
        }

        return Text(title)
    }

    private static func setFont(_ font: Font, for fragment: String, in title: inout AttributedString) {
        guard let range = title.range(of: fragment.trimmingCharacters(in: .whitespaces)) else { return }
        title[range].font = font
    }

    private static func setStrikethrough(for fragment: String, in title: inout AttributedString) {
        guard let range = title.range(of: fragment.trimmingCharacters(in: .whitespaces)) else { return }
        title[range].strikethroughStyle = .single
    }
}

struct MacStickyConfigurationHeading: View {
    let configuration: MacStickyConfiguration

    @ViewBuilder
    var body: some View {
        if case .category(let category) = configuration.source,
           category != .all,
           category != .completed {
            MacQuadrantHeading(category: category, font: .body)
        } else {
            Text(configuration.source.title)
        }
    }
}

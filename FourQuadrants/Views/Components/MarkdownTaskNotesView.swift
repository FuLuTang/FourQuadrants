import SwiftUI

struct MarkdownTaskNotesView: View {
    let text: String
    var onToggleChecklistItem: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if let item = ChecklistItem(line: line) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Button {
                            onToggleChecklistItem?(index)
                        } label: {
                            Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isChecked ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(onToggleChecklistItem == nil)
                        .accessibilityLabel(item.isChecked ? "标记为未完成" : "标记为已完成")

                        markdownText(item.content)
                            .strikethrough(item.isChecked, color: .secondary)
                            .foregroundStyle(item.isChecked ? .secondary : .primary)
                    }
                    .padding(.leading, CGFloat(item.indentationLevel * 16))
                } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    markdownText(line)
                }
            }
        }
    }

    private var lines: [String] {
        text.components(separatedBy: .newlines)
    }

    private func markdownText(_ value: String) -> Text {
        guard let attributed = try? AttributedString(
            markdown: value,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else { return Text(value) }
        return Text(attributed)
    }
}

struct MarkdownTaskNotesEditor: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Button {
                    insertChecklistItem()
                } label: {
                    Image(systemName: "checklist")
                }
                .buttonStyle(.borderless)
                .help("插入待办项")
                .accessibilityLabel("插入待办项")
            }

            if text.components(separatedBy: .newlines).contains(where: { ChecklistItem(line: $0) != nil }) {
                MarkdownTaskNotesView(text: text, onToggleChecklistItem: toggleChecklistItem)
                Divider()
            }

            TextEditor(text: $text)
                .frame(minHeight: 96)
        }
    }

    private func insertChecklistItem() {
        if text.isEmpty {
            text = "- [ ] "
        } else if text.hasSuffix("\n") {
            text += "- [ ] "
        } else {
            text += "\n- [ ] "
        }
    }

    private func toggleChecklistItem(at index: Int) {
        var lines = text.components(separatedBy: .newlines)
        guard lines.indices.contains(index), let item = ChecklistItem(line: lines[index]) else { return }
        lines[index] = item.toggledLine
        text = lines.joined(separator: "\n")
    }
}

private struct ChecklistItem {
    let originalLine: String
    let markerRange: Range<String.Index>
    let isChecked: Bool
    let content: String
    let indentationLevel: Int

    init?(line: String) {
        let patterns = ["- [ ]", "- [x]", "- [X]", "* [ ]", "* [x]", "* [X]", "[ ]", "[x]", "[X]"]
        let leadingCount = line.prefix { $0 == " " || $0 == "\t" }.count
        let trimmedStart = line.index(line.startIndex, offsetBy: leadingCount)
        let remainder = String(line[trimmedStart...])
        guard let marker = patterns.first(where: { remainder.hasPrefix($0) }) else { return nil }
        let markerEnd = line.index(trimmedStart, offsetBy: marker.count)

        originalLine = line
        markerRange = trimmedStart ..< markerEnd
        isChecked = marker.contains("[x]") || marker.contains("[X]")
        content = String(line[markerEnd...]).trimmingCharacters(in: .whitespaces)
        indentationLevel = line.prefix(leadingCount).reduce(into: 0) { count, character in
            count += character == "\t" ? 1 : 0
            if character == " " { count += 1 }
        } / 2
    }

    var toggledLine: String {
        var line = originalLine
        guard let bracket = line[markerRange].firstIndex(of: "[") else { return line }
        let valueIndex = line.index(after: bracket)
        line.replaceSubrange(valueIndex ... valueIndex, with: isChecked ? " " : "x")
        return line
    }
}

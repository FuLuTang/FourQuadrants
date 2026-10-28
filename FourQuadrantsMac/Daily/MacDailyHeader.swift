import SwiftUI

struct MacDailyHeader: View {
    let date: Date
    let hasSelection: Bool
    let isSelectionCompleted: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    let onDateChange: (Date) -> Void
    let onNew: () -> Void
    let onEdit: () -> Void
    let onToggleCompletion: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                .help("前一天")
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                DatePicker("日期", selection: Binding(get: { date }, set: onDateChange), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: 190)
                    .accessibilityLabel("选择日期")

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
                .help("后一天")
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("今天", action: onToday)
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.title3.weight(.semibold))
                Text(date.formatted(.dateTime.year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            if hasSelection {
                Button(isSelectionCompleted ? "标为未完成" : "标为完成", systemImage: "checkmark.circle") { onToggleCompletion() }
                    .help("切换日程完成状态")
                Button("编辑", systemImage: "pencil", action: onEdit)
                    .keyboardShortcut("e", modifiers: [.command])
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
                .help("删除所选日程")
            }

            Button(action: onNew) {
                Label("新建日程", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }
}

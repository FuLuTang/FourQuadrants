import SwiftUI

struct MacTaskCommonFields: View {
    @Binding var title: String
    @Binding var notes: String
    @Binding var importance: ImportanceLevel
    @Binding var isUrgent: Bool
    @Binding var isTop: Bool
    @Binding var isCompleted: Bool
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    let showsCompletion: Bool
    let hasAutomaticUrgency: Bool
    let effectiveUrgency: Bool
    let onSubmitTitle: (() -> Void)?
    @FocusState private var titleFocused: Bool

    var body: some View {
        Section("任务内容") {
            TextField("任务名称", text: $title)
                .focused($titleFocused)
                .onSubmit { onSubmitTitle?() }
            LabeledContent("备注") {
                TextEditor(text: $notes)
                    .frame(minHeight: 76)
            }
        }

        Section("分类与状态") {
            Picker("重要程度", selection: $importance) {
                Text("低").tag(ImportanceLevel.low)
                Text("普通").tag(ImportanceLevel.normal)
                Text("高").tag(ImportanceLevel.high)
            }
            .pickerStyle(.segmented)

            if hasAutomaticUrgency {
                Toggle("自动标记紧急", isOn: .constant(effectiveUrgency))
                    .disabled(true)
            } else {
                Toggle("手动标记紧急", isOn: $isUrgent)
            }
            Toggle("置顶", isOn: $isTop)
            if showsCompletion {
                Toggle("已完成", isOn: $isCompleted)
            }
        }

        Section("目标日期") {
            Toggle("设置截止日期", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("截止日期", selection: $dueDate, displayedComponents: .date)
            }
        }
    }
}

import SwiftUI

struct MacTaskCommonFields: View {
    @Binding var draft: MacTaskDraft
    let showsCompletion: Bool
    let onSubmitTitle: (() -> Void)?
    var autoFocusTitle = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        Section("任务内容") {
            TextField("任务名称", text: $draft.title)
                .focused($titleFocused)
                .onSubmit { onSubmitTitle?() }
                .onAppear { if autoFocusTitle { titleFocused = true } }
            LabeledContent("备注") {
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 76)
            }
        }

        Section("分类与状态") {
            Picker("重要程度", selection: $draft.importance) {
                Text("低").tag(ImportanceLevel.low)
                Text("普通").tag(ImportanceLevel.normal)
                Text("高").tag(ImportanceLevel.high)
            }
            .pickerStyle(.segmented)

            if draft.hasAutomaticUrgency {
                Toggle("自动标记紧急", isOn: .constant(draft.effectiveUrgency()))
                    .disabled(true)
            } else {
                Toggle("手动标记紧急", isOn: $draft.isUrgent)
            }
            Toggle("置顶", isOn: $draft.isTop)
            if showsCompletion {
                Toggle("已完成", isOn: $draft.isCompleted)
            }
        }

        Section("目标日期") {
            Toggle("设置截止日期", isOn: $draft.hasDueDate)
            if draft.hasDueDate {
                DatePicker("截止日期", selection: $draft.dueDate, displayedComponents: .date)
            }
        }
    }
}

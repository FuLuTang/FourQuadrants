 ai自用文档，按条目记录行动进度（甚至拆分小任务，以及记录小任务进度）

## Microsoft To Do Sync (Planned)
- **Library**: MSAL (Microsoft Authentication Library) for iOS.
- **API**: Microsoft Graph API (`/me/todo/lists`).
- **Scopes**: `Tasks.ReadWrite`, `User.Read`.
- **Pre-requisites**: 
    - Register App in Azure Portal.
    - Obtain Client ID.
    - Configure URL Scheme in Info.plist (`msauth.<BundleID>`).
- **Mapping Strategy**: Use `categories` in MS ToDo to sync the "Urgent" status since MS To Do has no native urgency field.
- **Conflict Handling**: Compare `lastModifiedDateTime` from Graph API with `dateLatestModified` in SwiftData.

---

## 长按预览功能 (Context Menu Preview) - 开发注意

### ⚠️ 关键问题：手势冲突
- `onTapGesture` 会与 `contextMenu` 的长按手势冲突
- **解决方案**：在使用 `contextMenu` 的视图上，将 `onTapGesture` 放在 `contextMenu` **之后**
- 或者使用 `simultaneousGesture` / `highPriorityGesture` 来处理优先级

### 期望效果（参考 iOS 原生 App）
- 长按触发：类似相册 App 长按图片、邮件 App 长按邮件
- 显示预览视图 + 菜单按钮（完成、删除、编辑）
- 松手后保持菜单，点击菜单项或空白处关闭

### 正确的 contextMenu 用法
```swift
.contextMenu {
    Button { } label: { Label("完成", systemImage: "checkmark") }
    Button { } label: { Label("编辑", systemImage: "pencil") }
    Button(role: .destructive) { } label: { Label("删除", systemImage: "trash") }
} preview: {
    TaskPreviewView(task: task)
}
```

### 修改顺序
1. 先应用 `.contextMenu`
2. 再应用 `.onTapGesture`（如果需要的话）

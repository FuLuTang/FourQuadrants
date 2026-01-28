 ai自用文档，按条目记录行动进度（甚至拆分小任务，以及记录小任务进度）

## 🧠 AI Agent 协作白板 (The Blackboard)

### 🏗️ Architect Status (主手)
- **当前分支**: `main`
- **正在进行**: 暂无任务

### 🛠️ Integrator Status (副手)
- **当前分支**: N/A
- **正在进行**: 暂无任务

### 📣 跨角色变更公告 (Schema Changes Log)
- *(此处记录所有涉及 TaskModel 的字段修改，格式：日期-角色-内容)*

## Microsoft To Do Sync (Planned)
- **Library**: MSAL (Microsoft Authentication Library) for iOS.
- **API**: Microsoft Graph API (`/me/todo/lists`).
- **Scopes**: `Tasks.ReadWrite`, `User.Read`.
- **Mapping Strategy**: Use `categories` in MS ToDo to sync the "Urgent" status since MS To Do has no native urgency field.
- **Conflict Handling**: Compare `lastModifiedDateTime` from Graph API with `dateLatestModified` in SwiftData.

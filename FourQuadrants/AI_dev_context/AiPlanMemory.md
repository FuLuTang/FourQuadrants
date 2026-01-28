 ai自用文档，按条目记录行动进度（甚至拆分小任务，以及记录小任务进度）

## 🧠 AI Agent 协作白板 (The Blackboard)

### 🏗️ Architect Status (主手)
- **当前分支**: `main`
- **正在进行**: 暂无任务

### 🛠️ Integrator Status (副手)
- **当前分支**: N/A
- **正在进行**: 暂无任务

### 🎨 UI Specialist Status (视觉设计)
- **当前分支**: `feat/ui-next-gen`
- **正在进行**: 角色认领，环境准备

### 📣 跨角色变更公告 (Schema Changes Log)
- *2026-01-28 - Sync Engineer - Added `msTodoId` (String?) and `msLastModified` (Date?) compatible with Microsoft Graph API.*

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

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

# 工程架构 (Architecture)

本文只记录能从代码核实的结构。Microsoft 字段映射见 `MicrosoftTodoCompatibility.md`，持久化细节见 `Persistence.md`，Mac 界面边界见 `macOS-Design.md`。

## Target 与共享关系

| Target | 说明 |
| --- | --- |
| `FourQuadrants` | iOS 应用，同步目录 `FourQuadrants/`（`Models`、`Services`、`Views`、`Resources`）。 |
| `FourQuadrantsMac` | 原生 macOS 应用，同步目录 `FourQuadrantsMac/`，同时编入 `FourQuadrants/` 中的共享代码；排除 `LiveActivityAttributes`、`LiveActivityManager` 与 `ColorStyle.plist`，`Info.plist` 使用 Mac 自己的。 |
| `FourQuadrantsWidgetExtension` | 小组件，目录 `FourQuadrantsWidget/`；显式编入共享的 `Models`、`PersistenceController`、`TaskStore`、`WidgetSnapshotService`、`CompleteWidgetTaskIntent`、`WidgetTaskActionService`、`DesignSystem`。 |
| `FourQuadrantsMacTests` / `FourQuadrantsTests` 等 | 测试与 Watch target。 |

iOS 与 Mac 共用 `Resources/{en,zh-Hans}.lproj/Localizable.strings`。

## 数据层（共享）

- **模型**（`Models/`）：`QuadrantTask`（四象限任务）、`DailyTask`（日程，可关联一个 `QuadrantTask`）、`TaskCategory`、以及 Microsoft 同步模型。全部登记在 `AppSchemaV1`。
- **`PersistenceController`**：创建 `ModelContainer`、重置存储。路径见 `Persistence.md`。
- **`AppDataController`**（`@Observable`）：持有 `state`（`loading` / `ready(AppDataSession)` / `recoveryRequired`）。`AppDataSession` 含 `ModelContainer` 与 `TaskStore`。打开存储后调用 `SyncService.shared.configure` 并设置小组件完成回调；提供 `retry()` 与 `resetLocalData()`。预览数据模式用独立内存容器创建，可不配置同步。
- **`TaskStore`**（`@MainActor @Observable`）：任务与日程的所有写入口（增删改、完成切换、`moveTask(_:to:)`、日程移动与布局预览/提交）以及 `filteredTasks`、`sortTasks`。象限任务的写入通过 `commitQuadrantTaskMutation`：执行修改，调用 `quadrantTaskMutationRecorder`（同步 outbox 记录），保存，写小组件快照，最后调用 `quadrantTaskMutationDidCommit`；任一步失败则 `rollback()` 并设置 `lastErrorMessage`。
- **`TaskOrdering`**（`TaskStore.swift` 内）：纯排序函数。`sorted(_:by:direction:)` 支持智能、截止日期、创建时间、名称；`recommended(_:limit:)` 供小组件推荐。

## 象限判定

`QuadrantTask` 保存 `importance`、`manualIsUrgent`、`dueDateKey`（`yyyy-MM-dd` 形式的日期键）、`urgentThresholdDays` 以及 `originalImportance` / `originalUrgentThresholdDays`。紧急度由截止日期与阈值自动判定，无则读 `manualIsUrgent`；`TaskStore.moveTask` 在跨象限移动时调整这些字段。具体规则以 `QuadrantTask.swift` 与 `TaskStore.moveTask` 为准。

## Microsoft To Do 同步（`SyncService`）

`SyncService`（`ObservableObject`，单例 `shared`）负责登录（MSAL）、拉取、推送与诊断。本地数据靠四个同步模型维持一致：

- `MicrosoftTodoSyncProfile`：账户、默认列表、`deltaLink`、是否启用、是否完成首次合并、最近成功同步时间。
- `MicrosoftTodoTaskLink`：本地任务与远程任务的链接，含 etag、远程字段的 shadow 副本与 `MicrosoftTodoLinkState`（`linked`、`pendingUpload`、`pendingLocalDeletion` 等）。
- `MicrosoftTodoSyncOperation`（outbox）：`create` / `update` / `delete` 操作，状态为 `queued`、`inFlight`、`uncertain`、`retryableFailure`、`conflict`、`permanentFailure`，记录尝试次数与下次尝试时间。
- `MicrosoftTodoDeletionTombstone`：本地删除已同步任务时保留远程标识，防止删除被拉取结果覆盖。

流程：`TaskStore` 的 recorder 在保存前调用 `recordDurableMutation`，写入链接与 outbox 记录（删除时写 tombstone）；提交成功后 `quadrantTaskMutationDidCommit` 触发后台投递。`synchronize()` 先 `pullRemoteChanges`（delta 查询），再 `pushLocalChanges` 投递 outbox；有待投递本地修改的任务不会被拉取结果覆盖（`shouldKeepPendingLocalChange`）。首次登录需要用户在首次合并中选择上传哪些本地任务（`completeInitialMerge`）。日程（`DailyTask`）不参与同步。

## 小组件快照

`WidgetSnapshotService.write(context:)` 在任务提交后写 App Group 中的 `widget-snapshot.json`（推荐任务、各象限计数与任务）。仅 iOS 编译写入与 `WidgetKit` 刷新；小组件通过 `WidgetSnapshotStore` 读取。macOS 不写快照。小组件中的完成操作经 `WidgetTaskCompletionBridge.complete` 回到 `TaskStore.toggleTask`。

## iOS 界面

`FourQuadrantsApp` + `MainView`，视图在 `Views/`（含 `DailyView`、象限与表单组件）。

## Mac 模块（`FourQuadrantsMac/`）

- **App**：`FourQuadrantsMacApp`（主窗口、菜单栏、设置窗口）、`MacApplicationRuntime`（一个 `AppDataController` 会话、路由状态 `pendingRoute`、`fourquadrants://task/<uuid>` 链接、`--preview-data` 与 `--preview-stickies` 启动参数）、`MacCommands`（菜单命令）、`MacPreviewData`。
- **Workspace**：`MacWorkspaceView` 与侧栏/工具栏/内容路由、四象限看板、任务列表与行、检查器、新建/编辑表单、`MacTaskDraft`（检查器与表单共用的草稿）、设置（外观、同步、关于）、同步状态与诊断、首次合并、数据恢复。
- **Daily**：日程视图、时间轴布局与拖拽数学、日程表单、关联任务选择与关键词建议。
- **Stickies**：ToDo便笺。`MacStickyCoordinator`（配置与对外接口）、`MacStickyConfigurationStore`（UserDefaults，防抖写入）、`MacStickyPanelController`（`NSPanel`）、`MacStickyViews` / `MacStickyMenu`。契约见 `FourQuadrantsMac/Stickies/IntegrationContract.md`。
- **Platform**：系统适配（目前为 MSAL 认证窗口 `MacAuthenticationPresentation`）。

所有窗口通过同一个 `TaskStore` 写入数据，Mac 不单独实现任务规则。

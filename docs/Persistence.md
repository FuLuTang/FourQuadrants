# 数据持久化 (Persistence)

## 存储

- 使用 SwiftData，`AppSchemaV1`（版本 1.0.0）包含六个模型：`QuadrantTask`、`DailyTask`、`MicrosoftTodoSyncProfile`、`MicrosoftTodoTaskLink`、`MicrosoftTodoSyncOperation`、`MicrosoftTodoDeletionTombstone`。尚未发布过旧版本，代码中没有迁移计划；早期原型数据库不受支持。
- 配置名 `FourQuadrants-v1`，文件名 `FourQuadrants-v1.store`，`cloudKitDatabase: .none`。
- `QuadrantTask.dailyTasks` 与 `DailyTask.quadrantTask` 为一对多关系，删除规则 `.nullify`：删除象限任务不会删除日程。

## 存储位置（`PersistenceController.storeURL()`）

| 平台 | 路径 |
| --- | --- |
| iOS / 小组件 | App Group 容器根目录。Debug：`group.fulu.FourQuadrants.dev`；Release：`group.fulu.FourQuadrants`。容器不可用时抛 `appGroupUnavailable`。 |
| macOS | `~/Library/Application Support/FourQuadrantsMac/` |

## 打开与恢复

`AppDataController` 调用 `makeContainer()`；失败进入 `recoveryRequired`，界面提供重试与重置。`resetStore()` 删除 store 及其 `-wal`、`-shm` 文件后重新打开。测试使用 `PersistenceController.inMemoryContainer()`；Mac 的 `--preview-data` 使用独立内存容器。

## 写入规则

- 任务与日程的写入统一经过 `TaskStore`。象限任务修改在同一次保存前写入同步 outbox，保存失败则 `rollback()`，见 `Architecture.md`。
- 日期使用 `dueAt`（时刻）与 `dueDateKey`（日期键）。
- 小组件快照 `widget-snapshot.json` 位于 App Group，仅 iOS 写入，是缓存而非数据来源。

## 不在 SwiftData 中的 Mac 数据

ToDo便笺的窗口配置存于 `UserDefaults`（键 `FourQuadrants.macStickies.configurations.v1`），主题等偏好存于 `@AppStorage`。它们只在本机生效，不参与同步。

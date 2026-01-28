# 数据持久化 (Persistence)

## 💾 存储方案

项目目前采用 **JSON 文件持久化** 方案，存储在 iOS 的 **App Group** 共享容器中。

### 为什么选择 App Group？
为了支持后续的 **Widget (小组件)** 和 **Live Activity (灵动岛)** 功能。
- 主 App 与小组件属于不同的进程。
- 只有存储在 App Group 目录下的数据，才能在主 App 修改后被小组件即时读取。

### 技术实现 (`PersistenceManager.swift`)
- **路径**: `group.com.fulu.FourQuadrants` 标识符所对应的文件夹。
- **编码**: 使用 `JSONEncoder` 进行序列化。
- **触发机制**: 每次 `TaskManager` 中的任务发生变动（添加、修改、删除、完成）时，都会全量保存至磁盘。

## 🛠 未来规划
随着数据量增大，可能会平滑升级至 **SwiftData**，以提供更快速的索引和查询能力。

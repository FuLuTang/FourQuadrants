# 数据持久化 (Persistence)

## 💾 存储方案

项目目前已升级为 **SwiftData** (Apple 官方数据库) 方案。
 
 ### 为什么选择 SwiftData？
 SwiftData 是 Core Data 的现代替代品，提供原生的 Swift 体验，具备以下优势：
 - **性能**：基于 SQLite，无需全量加载数据，内存占用低。
 - **查询**：支持复杂的谓词 (Predicate) 过滤和排序。
 - **多端同步**：为未来支持 iCloud CloudKit 自动同步打下基础。
 
 ### 技术实现
 - **模型**: `Task` 类使用 `@Model` 宏标记。
 - **容器**: 在 `FourQuadrantsApp` 中注入 `.modelContainer`。
 - **操作**: `TaskManager` 使用 `ModelContext` 进行 CRUD 操作。
 
 ## 🛠 废弃方案 (Legacy)
 之前的 JSON 文件存储方案 (`PersistenceManager.swift`) 已被废弃并移除。

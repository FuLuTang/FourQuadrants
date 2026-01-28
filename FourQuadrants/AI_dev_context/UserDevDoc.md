- 你应及时更改此文件文字内容，和移动条目和划线

# 🚀 待办开发内容 (Active Backlog)

## 第二部分：外部集成 (External Integration)
- **Microsoft To Do 同步**：通过 Microsoft Graph API 实现与微软待办的双向同步。
  - 集成 MSAL 认证。
  - 处理任务 ID 映射与冲突解决。
  - 支持后台增量更新。

## 第三部分：发展规划 (Future Development)
- **异步处理 (Concurrency)**：使用 `async/await` 处理网络请求与重型数据库操作。

## 第三部分：商业功能扩展
- **搜索与筛选**：增加基于关键字的实时搜索功能。
- **数据可视化**：增加“周报/月报”统计图表。
- **交互细节**：增加 Haptic Feedback 反馈和精细转场动画。

---

# 💡 开发者层面的“长期展望”建议
虽然一个 Target 够用，但为了让你作为 INTP 的代码逻辑更严谨，建议在项目文件夹里这样组织：
- **FourQuadrantsWidget.swift**：放最基础操 2x2 或 4x4 矩阵小组件。
- **LiveActivityManager.swift**：专门写启动、更新、关闭灵动岛的逻辑。
- **LiveActivityView.swift**：专门写灵动岛在那四种状态（紧凑型、扩展型、最小型）下的 UI 代码。

---

# 废弃信息（已记入Readme/Features）
~~以下内容已归档~~

### 1. 核心逻辑修复
- [x] **修复逾期判断 Bug**：修改 `Task.isOverdue` 逻辑。目前的逻辑会导致没有截止日期的任务全部显示逾期。应改为：若 `targetDate` 为空，则 `isOverdue` 永远为 `false`。
- [x] **紧急程度自动更新**：目前 `updateUrgency` 函数是手动调用的。建议将其逻辑整合进 `isUrgent` 的计算属性，或在 `TaskManager` 中通过计时器/生命周期定期刷新。

### 2. 架构模式优化 (MVVM Purity)
- [x] **瘦身 View 层**：将 `ListView` 中的 `filteredTasks` 等复杂的过滤、排序逻辑全部移入 `TaskManager.swift` (ViewModel)。View 应该只负责展示。
- [x] **解耦显示逻辑**：将 `TaskCategory` 的原始值从带 Emoji 的字符串改为简洁的纯英文 Key。Emoji 展示应在 View 层处理。

### 3. UI/UX 微调
- [x] **状态切换体验**：优化 `toggleTask` 的 3 秒延迟逻辑，确保快速点击时的状态同步。
- [x] **重要性分级对齐**：明确 `ImportanceLevel`（三级）与四象限（两极）的映射逻辑。

### 4. 发展规划落地
- [x] **数据持久化落地 (Persistence)**：成功实现从内存到 SwiftData 数据库的跨越。
- [x] **架构解耦**：将所有数据库操作逻辑整合进 TaskManager，解耦了视图层。
- [x] **多语言支持 (Localization)**：引入 `Localizable.strings` 管理字符串。
- [x] **单元测试 (Unit Testing)**：编写 XCTest 测试排序算法和逾期逻辑。
- [x] **SwiftData 迁移**：从 JSON 持久化迁移到 Apple 官方的 SwiftData 框架，提升性能和数据管理能力。
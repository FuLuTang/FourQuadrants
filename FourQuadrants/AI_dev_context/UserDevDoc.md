- 你不可更改此文件文字内容，仅可移动条目和划线

# 开发内容
# 🚀 项目改进与发展建议文档 (TASKS.md)

## 第一部分：当前修复与优化 (Immediate Fixes & Optimizations)
*目标：解决逻辑漏洞，提升代码健壮性，达到“准上架”的状态。*

### 1. 核心逻辑修复
- [x] **修复逾期判断 Bug**：修改 `Task.isOverdue` 逻辑。目前的逻辑会导致没有截止日期的任务全部显示逾期。应改为：若 `targetDate` 为空，则 `isOverdue` 永远为 `false`。
- [x] **紧急程度自动更新**：目前 `updateUrgency` 函数是手动调用的。建议将其逻辑整合进 `isUrgent` 的计算属性，或在 `TaskManager` 中通过计时器/生命周期定期刷新。

### 2. 架构模式优化 (MVVM Purity)
- [x] **瘦身 View 层**：将 `ListView` 中的 `filteredTasks` 等复杂的过滤、排序逻辑全部移入 `TaskManager.swift` (ViewModel)。View 应该只负责展示。
- [x] **解耦显示逻辑**：将 `TaskCategory` 的原始值从带 Emoji 的字符串改为简洁的纯英文 Key。Emoji 展示应在 View 层处理。

### 3. UI/UX 微调
- [x] **状态切换体验**：优化 `toggleTask` 的 3 秒延迟逻辑，确保快速点击时的状态同步。
- [x] **重要性分级对齐**：明确 `ImportanceLevel`（三级）与四象限（两极）的映射逻辑。

---

## 第二部分：发展规划 (Future Development)
*目标：提升项目专业度，为简历增色，并向成熟商业应用靠拢。*

### 1. 数据持久化落地 (Persistence)
- [x] **引入持久化层**：从内存存储切换到 **SwiftData** (推荐) 或 JSON 文件存储。（已实现 JSON AppGroup 存储）
- [x] **架构解耦**：创建专门的 `PersistenceManager` 或 Service 类，隔离读写逻辑。

### 2. 专业工程化实践
- [x] **多语言支持 (Localization)**：引入 `Localizable.strings` 管理字符串。
- **单元测试 (Unit Testing)**：编写 XCTest 测试排序算法和逾期逻辑。
- **异步处理 (Concurrency)**：学习使用 Swift 的 `async/await` 处理潜在的耗时任务。

### 3. 商业功能扩展
- **搜索与筛选**：增加基于关键字的实时搜索功能。
- **数据可视化**：增加“周报/月报”统计图表。
- **交互细节**：增加 Haptic Feedback 反馈和精细转场动画。


开发者层面的“长期展望”建议
虽然一个 Target 够用，但为了让你作为 INTP 的代码逻辑更严谨，建议在项目文件夹里这样组织：

FourQuadrantsWidget.swift：放最基础的 2x2 或 4x4 矩阵小组件。

LiveActivityManager.swift：专门写启动、更新、关闭灵动岛的逻辑。

LiveActivityView.swift：专门写灵动岛在那四种状态（紧凑型、扩展型、最小型）下的 UI 代码。




# 废弃信息（已记入Readme）
~~以下~~
- 你应及时更改此文件文字内容，和移动条目和划线
> 你只能移动，添加，修改标记。不能删除

# 🚀 待办开发内容 (Active Backlog)

## 第一部分：核心 P0 (Top Priority)

### 🔴 当前进行中：灵动岛 (Live Activities)
- **灵动岛支持**：在每日任务进行时提供实时状态展示
  - [x] SwiftData 配置 App Group 共享路径
  - [x] 重写 `ContentState` 数据结构 (LiveActivityAttributes.swift)
  - [ ] 实现 LiveActivity UI（Expanded/Compact/Minimal）← **当前阻塞项**
  - [x] 主 App 添加 `checkTask()` 定时检查逻辑
  - [ ] 测试多任务重叠场景
  - [x] 详细方案见 `LiveActivity.伪代码` 和 `AiProjectDetailMemory.md`
  - [ ] UI优化升级（找用户要figma预览）

### 🟡 待开发
- ~~设置页面~~
  - [x] “通知”开关修复
  - [x] “深色模式”开关修复
  - [x] 多语言文字补充

- **Microsoft To Do 同步**：通过 Microsoft Graph API 实现与微软待办的双向同步
  - 集成 MSAL 认证，处理 OAuth 流程
  - 同步逻辑开发：处理 `Task` 的 ID 映射与冲突
- **iOS 桌面小组件 (WidgetKit)**：支持主屏幕 2x2, 4x4 小组件展示各象限任务

## 第二部分：质感提升 (Premium UX)
- **长按预览功能（原生 Context Preview）**：
  - **Task 长按**：弹出小窗口显示该任务的所有参数信息（松手消失）
  - **象限窗格长按**：类似 `TaskListView` 的任务列表展示（探索复用组件）
  - ⚠️ 需测试：Task 长按与象限长按是否存在手势冲突（已知：冲突。能长按小项目，但是大背景块没反应）
- **触感反馈 (Haptic Feedback)**：在勾选、拖拽、删除时加入精细震动反馈
- **异步基建优化**：使用 `async/await` 重构数据读写逻辑，避免主线程阻塞
- **智能关联 TaskList**：创建每日任务时自动推荐关联（向量搜索）
  - 技术栈：`NaturalLanguage` + `Accelerate (vDSP)` + `SwiftData`
  - 详细方案见 `AiProjectDetailMemory.md`
- **每日页面**：效果优化
  - 滑块两个大状态，普通态和“编辑”态（未包含现有其他小态，需要融合）
    - 普通态：点击打开编辑，长按进编辑态，长按滑动拖动编辑时间位置
    - 编辑态：块顶靠左，块底靠右，各加一个小圆（没作用）。长按顶边和底边可以调整时间；普通（无长按）滑动可以调整时间位置；
  - 所有滑动调整时间行为，都应该卡着15分钟的格子刻度
    - 写一个新的“吸附”函数
    - 显示，应该闪现，咯噔咯噔的。现有版本会精确地显示拖动时的精确时间，只有松手才吸附到最近的15分钟刻度，这样很怪。（包括调整范围和调整位置）
    - 每次触发吸附行为都调用一次原生的清脆的震动
  - dateheader的三部分，中间部分左右滑切换日期时，文字也会左右移动然后消失（跟随手指），可以看看有没有原生的做法
  - 顶部的剩下的最后那顶边，完全直接延伸还是不那么好看，还是加个模糊渐变吧，可以用最原生的方法（比如head自带的效果）

## 第三部分：Icebox (冷宫/延后)
- **搜索与筛选**：关键字搜索。由于四象限提倡精简任务，此功能优先级下调
- **数据可视化**：周报图表

## ✅ 已完成：今日视图 (Daily Planner)
- [x] 底栏新增「今日」Tab：每日时间规划功能
- [x] 参考 iOS 日历 App 日视图布局（24小时时间轴）
- [x] 任务块按时间段排列，当前时间红线实时更新
- [x] **高级手势交互**：基于 UIKit 重写，支持长按即刻生成、无感滑动、15/30分钟智能吸附。

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
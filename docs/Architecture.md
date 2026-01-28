# 工程架构 (Architecture)

## 🏛 核心模式：MVVM

本项目采用了标准的 **MVVM (Model-View-ViewModel)** 架构，以确保逻辑与界面的深度解耦：

- **Model (`TaskModel.swift`)**:
  - 核心数据模型，使用 SwiftData (`@Model`) 管理字段。
  - 包含 `isUrgent` (紧急判断) 和 `isOverdue` (逾期判断) 的精密计算逻辑。
- **ViewModel (`TaskManager.swift`)**:
  - 作为唯一的事实来源（Single Source of Truth）。
  - 处理任务的数据库操作 (CRUD)。
  - **核心逻辑**：执行 `filteredTasks` 分类算法、`sortTasks` 智能排序算法，以及 `dragTaskChangeCategory` 交互同步逻辑。
- **View (`Views/`)**:
  - 纯响应式界面，通过 `@ObservedObject` 观察 TaskManager 的状态变化。

## 🧩 四象限与智能判定逻辑

### 1. 象限映射原理
系统根据 `importance` 和 `isUrgent` 进行动态映射：
- **重要度**: 仅当 `importance == .high` 时视为重要。
- **紧急度**: 基于以下双轨制逻辑计算：

### 2. 紧急判断“双轨制” (Urgency Logic)
- **自动轨道 (Automatic)**: 若任务有“目标日期”和“紧急阈值”，系统自动计算剩余天数。若 `剩余天数 <= 阈值`，任务自动变为紧急。
- **手动轨道 (Manual)**: 若无日期或手动干预，读取 `manualIsUrgent` 属性值作为准则。

### 3. 拖拽同步机制 (Drag & Drop Sync)
当用户跨象限拖拽任务时，ViewModel 会自动调整底层数据以匹配视觉位置：
- 拖入紧急区：若有日期，则自动倒推并设置 `urgentThresholdDays`；若无日期，则开启手动紧急开关。
- 拖入重要区：强制设 `importance` 为 `.high`。
- 这种机制实现了“所见即所得”的交互式数据维护。

## 🌐 外部同步架构 (Sync Strategy)

为了支持 **Microsoft To Do** 同步，架构将引入新的层级：

### 1. 外部 ID 映射
- `Task` 模型将增加 `msTodoId: String?` 字段。
- 只有具备该 ID 的任务才会参与远程更新，本地新建任务在首次同步成功后获取 ID。

### 2. 同步逻辑策略
- **单向 Push**: 本地修改后，通过 `TaskManager` 监听并异步推送至 Graph API。
- **全量 Pull**: App 启动或下拉刷新时，获取远程列表，对比 `dateLatestModified` 时间戳进行冲突解决。

### 3. 数据映射字典
- `Importance`: 本地 `.high` <-> 远程 `importance: high`。
- `Urgency`: 本地 `isUrgent` <-> 远程 `categories` (添加 "Urgent" 标签)。

## 📂 目录说明
- `FourQuadrants/Views/`: 包含主视图、象限视图、列表视图和表单视图。
- `FourQuadrants/Services/`: 包含持久化、通知等服务类。
- `FourQuadrants/Resources/`: 国际化、资源文件。

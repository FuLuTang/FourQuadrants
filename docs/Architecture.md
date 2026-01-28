# 工程架构 (Architecture)

## 🏛 核心模式：MVVM

本项目采用了标准的 **MVVM (Model-View-ViewModel)** 架构，以确保逻辑与界面的深度解耦：

- **Model (`TaskModel.swift`)**:
  - 纯净的数据结构，不包含任何业务代码。
  - 使用 `Codable` 协议支持持久化。
  - 包含 `isUrgent` 和 `isOverdue` 的逻辑判定函数。
- **ViewModel (`TaskManager.swift`)**:
  - 作为唯一的事实来源（Single Source of Truth）。
  - 处理任务的增删改查。
  - **核心逻辑**：执行复杂的 `filteredTasks` 过滤算法和 `sortTasks` 排序算法。
  - 触发持久化写入。
- **View (`Views/`)**:
  - 纯响应式界面。
  - 通过 `@ObservedObject` 观察 TaskManager。
  - 不做任何逻辑计算，仅负责将 ViewModel 的状态呈现给用户。

## 🧩 四象限映射逻辑

系统将 1-10 的重要程度简化为象限映射：
- **重要 (Important)**: `ImportanceLevel == .high`
- **不重要 (Not Important)**: `ImportanceLevel == .normal` 或 `.low`

结合 `isUrgent` 的布尔值，形成四种分类：
1. 重要且紧急
2. 重要不紧急
3. 紧急不重要
4. 不重要不紧急

## 📂 目录说明
- `FourQuadrants/Views/`: 包含主视图、象限视图、列表视图和表单视图。
- `FourQuadrants/Services/`: 包含持久化、通知等服务类。
- `FourQuadrants/Resources/`: 国际化、资源文件。

# 质量保障 (Testing)

## ✅ 单元测试驱动开发

项目坚信“无测试，不交付”。所有核心逻辑必须通过 **Swift Testing** 框架的自动化验证。

### 核心测试点 (`FourQuadrantsTests.swift`)

1.  **逾期逻辑 (`testTaskOverdueLogic`)**:
    - 验证无日期任务不显示逾期。
    - 验证已完成任务不显示逾期。
    - 验证过期任务在未完成状态下正确显示红色。

2.  **自动紧急判定 (`testTaskUrgencyLogic`)**:
    - 验证紧急阈值（Urgent Threshold）对 `isUrgent` 计算属性的影响。
    - 验证当任务接近截止日期（进入阈值内）时，是否能自动变为紧急状态。

3.  **智能排序算法 (`testTaskManagerSorting`)**:
    - 权重验证：置顶 (Pinned) > 目标日期 (Target Date) > 重要性 (Importance) > 修改时间。
    - 确保用户最关心的任务始终浮动在应用顶部。

## 🚀 运行方法
在 Xcode 中按下 **`Command + U`**。

## 📊 质量文化
根据 `AI_dev_context/DevelopHabit.md` 的要求，任何涉及到 `Task` 逻辑和 `TaskManager` 排序的**新功能开发，必须同步更新或新增单元测试**。这确保了在项目快速迭代过程中，底层的业务逻辑始终保持强壮。

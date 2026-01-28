# FourQuadrants (四象限任务管理) 🚀

![Swift](https://img.shields.io/badge/Swift-5.10+-orange.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%20|%20WatchOS-blue.svg)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blueviolet.svg)

**FourQuadrants** 是一款基于“艾森豪威尔矩阵”（重要/紧急四象限）理论开发的高效率任务管理工具。它旨在通过科学的优先级划分，帮助用户从繁杂的事务中解脱出来，专注于核心价值。

---

## ✨ 核心特性

- **四象限视图**：直观的九宫格布局，优先级一目了然。
- **智能自动化**：
  - 自动根据“目标日期”和“紧急阈值”动态判定任务紧急程度。
  - 精准的逾期判断逻辑。
- **多端同步基石**：支持 App Group 容器存储，为 Widget 和 WatchOS 提供数据统一。
- **极致排序**：采用“智能排序算法”，自动置顶、提前期限任务。
- **现代化架构**：严谨的 MVVM 模式，纯 SwiftUI 开发。
- **自动化保障**：集成 XCTest 单元测试，确保核心逻辑稳如磐石。

---

## 🛠 技术栈

- **语言**: Swift 6
- **框架**: SwiftUI, Combine, SwiftData, Swift Testing
- **存储**: SwiftData (Apple 官方数据库方案)
- **多语言**: 支持中文、英文 (Localization)

---

## 💡 使用指南

### 1. 快速添加与分类
- 点击右上角的 **"+"** 按钮。
- **重要度 (Importance)**: 选择“高”会将任务映射到重要象限。
- **紧急度判定**: 
    - **自动**: 设置“目标日期”和“紧急阈值”，系统会自动变色/分流。
    - **手动**: 直接勾选“紧急”开关。

### 2. 灵动手势 (Drag & Drop)
- 在首页直接**长按并拖拽**任务到其它象限。
- 系统会根据你的放置位置，**智能倒推**底层属性（如修改重要等级或重设计算阈值），实现所见即所得。

### 3. 操作反馈机制
- **完成任务**: 点击圆圈。任务会停顿 3 秒供你最后确认，随后优雅消失。
- **深层数据**: 点击任务右侧的 `i` 按钮，可以查看任务从创建到现在的所有时间戳细节。

---

## 📖 深入文档

关于项目的详细实现逻辑，请参阅：

- [✨ 功能清单](./docs/Features.md) - 查看已实现的商用级功能与交互细节。
- [🏗 工程架构](./docs/Architecture.md) - 详解 MVVM 模式与四象限逻辑映射。
- [💾 数据持久化](./docs/Persistence.md) - 了解如何利用 App Group 实现数据存储。
- [🧪 质量保障](./docs/Testing.md) - 查看单元测试覆盖范围与验证逻辑。

---

## 🚀 快速开始

### 环境依赖
- Xcode 16.0+
- iOS 18.0+

### 安装与运行
1. 克隆仓库。
2. 在 Xcode 中打开 `FourQuadrants.xcodeproj`。
3. 确保运行目标选择 iOS 模拟器。
4. 按下 `Command + R` 运行 App，或按下 `Command + U` 运行测试用例。

---

## 📝 开发者习惯 (AI Dev Guidelines)

本项目在开发过程中严格遵循特定的开发习惯，详情可见：
- [AiRules.md](./FourQuadrants/AI_dev_context/AiRules.md)
- [DevelopHabit.md](./FourQuadrants/AI_dev_context/DevelopHabit.md)

---

## ⚖️ 愿景
让每一秒都花在真正重要的事务上。

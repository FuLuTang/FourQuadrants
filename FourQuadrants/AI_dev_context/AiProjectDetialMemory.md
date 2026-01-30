 ai自用文档，按条目记录行动进度（甚至拆分小任务，以及记录小任务进度）

## Microsoft To Do Sync (Planned)
- **Library**: MSAL (Microsoft Authentication Library) for iOS.
- **API**: Microsoft Graph API (`/me/todo/lists`).
- **Scopes**: `Tasks.ReadWrite`, `User.Read`.
- **Pre-requisites**: 
    - Register App in Azure Portal.
    - Obtain Client ID.
    - Configure URL Scheme in Info.plist (`msauth.<BundleID>`).
- **Mapping Strategy**: Use `categories` in MS ToDo to sync the "Urgent" status since MS To Do has no native urgency field.
- **Conflict Handling**: Compare `lastModifiedDateTime` from Graph API with `dateLatestModified` in SwiftData.

---

## 长按预览功能 (Context Menu Preview) - 开发注意

### ⚠️ 关键问题：手势冲突
- `onTapGesture` 会与 `contextMenu` 的长按手势冲突
- **解决方案**：在使用 `contextMenu` 的视图上，将 `onTapGesture` 放在 `contextMenu` **之后**
- 或者使用 `simultaneousGesture` / `highPriorityGesture` 来处理优先级

### 期望效果（参考 iOS 原生 App）
- 长按触发：类似相册 App 长按图片、邮件 App 长按邮件
- 显示预览视图 + 菜单按钮（完成、删除、编辑）
- 松手后保持菜单，点击菜单项或空白处关闭

### 正确的 contextMenu 用法
```swift
.contextMenu {
    Button { } label: { Label("完成", systemImage: "checkmark") }
    Button { } label: { Label("编辑", systemImage: "pencil") }
    Button(role: .destructive) { } label: { Label("删除", systemImage: "trash") }
} preview: {
    TaskPreviewView(task: task)
}
```

### 修改顺序
1. 先应用 `.contextMenu`
2. 再应用 `.onTapGesture`（如果需要的话）

---

## 每日任务智能关联 (Daily Task Auto-Linking) - 技术方案

### 📋 使用场景
用户在"今日视图"创建每日计划任务时（如 "写数学作业"），系统自动推荐 TaskList 中语义相似的任务（如 "maths p36-38"），一键建立关联。完成每日任务时，自动同步完成关联的 TaskList 任务。

### 🎯 核心需求
- **自动推荐**：创建每日任务时，后台计算与 TaskList 的语义相似度
- **一键确认**：弹出推荐卡片，用户点击确认即可关联
- **同步完成**：完成每日任务 → 自动完成关联的 TaskList 任务

### 🛠️ 技术路径（已验证）

#### 1. Embedding - NLEmbedding (简体中文模型)
```swift
import NaturalLanguage

// 初始化中文句子嵌入模型（iOS 13.0+）
guard let embedding = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese) else { 
    // 系统可能需要后台下载模型资源
    return 
}

// 将任务描述转为向量
if let vector = embedding.vector(for: "写数学作业") {
    // vector 是 [Double]，需转为 [Float] 存储
}
```

**技术特性**：
- ✅ **离线运行**：完全本地，不需要网络
- ✅ **中国区可用**：不依赖 Apple Intelligence
- ✅ **性能保证**：iPhone 12 (A14) 可流畅运行
- ⚠️ **首次使用**：系统会后台下载语言模型（约 50MB）

#### 2. 存储 - SwiftData 扩展

**TaskModel 增加向量字段**：
```swift
@Model
class QuadrantTask {
    // ... 现有字段 ...
    var embeddingData: Data?  // 存储 [Float] 的字节流
    
    // 向量转 Data 的辅助方法
    func setEmbedding(_ vector: [Float]) {
        embeddingData = Data(bytes: vector, count: vector.count * MemoryLayout<Float>.size)
    }
    
    func getEmbedding() -> [Float]? {
        guard let data = embeddingData else { return nil }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
```

**每日任务模型（新建）**：
```swift
@Model
class DailyPlanItem {
    var id: UUID
    var title: String
    var scheduledTime: Date
    var duration: TimeInterval
    var linkedTaskId: UUID?  // 关联的 QuadrantTask.id
}
```

#### 3. 相似度计算 - Accelerate (vDSP)

```swift
import Accelerate

func cosineSimilarity(_ vectorA: [Float], _ vectorB: [Float]) -> Float? {
    guard vectorA.count == vectorB.count, !vectorA.isEmpty else { return nil }
    
    // 使用 SIMD 指令加速（1万条 < 10ms）
    let dotProduct = vDSP.dot(vectorA, vectorB)
    let magnitudeA = sqrt(vDSP.sumOfSquares(vectorA))
    let magnitudeB = sqrt(vDSP.sumOfSquares(vectorB))
    
    guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
    return dotProduct / (magnitudeA * magnitudeB)
}
```

**性能优化建议**：
- 预归一化向量（存储时就归一化），相似度 = 点积（省掉除法）
- 使用 `Task.detached` 在后台线程计算，避免阻塞 UI

### ⚠️ 跨语言限制与解决方案

**问题**：NLEmbedding 中英文模型分离，"写数学作业" 和 "maths p36-38" 无法直接语义比较

**解决方案（混合策略）**：
1. **主策略**：使用简体中文模型（对中英混合有一定容忍度）
2. **辅助策略**：数字/符号关键词匹配（如 "p36" 可用正则提取）
3. **兜底方案**：始终提供手动选择关联的入口

**未来可选**：如果原生效果不够，可转换 `paraphrase-multilingual-MiniLM-L12-v2` (Sentence-Transformers) 到 CoreML

### 📐 实现步骤

| 阶段 | 任务 | 依赖 |
|------|------|------|
| **Phase 1** | 完成"今日视图"UI（时间轴 + 任务块） | 无 |
| **Phase 2** | 给 QuadrantTask 增加 `embeddingData` 字段 | SwiftData Migration |
| **Phase 3** | 后台生成所有任务的向量（懒加载/增量） | NLEmbedding |
| **Phase 4** | 创建每日任务时，计算相似度并推荐 Top 3 | vDSP |
| **Phase 5** | 完成每日任务 → 同步完成关联任务 | 简单逻辑 |

### 🎨 推荐的用户体验

```
用户输入 "写数学作业"
        ↓
系统后台计算相似度（< 50ms）
        ↓
弹出推荐卡片：
  🔗 关联任务？
  📝 maths p36-38 (相似度: 87%)
  [确认] [取消] [手动选择]
        ↓
用户点确认 → 建立关联
```

---

### 📅 每日视图 (Daily View) - 详细设计规划

#### 1. 核心 UI 元素复刻 (参考 iOS 原生日历)
- **顶部导航栏**：
  - 中间显示当前日期 "2026年1月30日"
  - 左右箭头 `< >` 切换日期 (滑动切换)
  - **点击日期**：弹出淡入淡出的 Mini Calendar (小日历) 供快速跳转
- **时间轴布局**：
  - **左侧时间轴**：00:00 - 23:00，灰色小字体，右对齐，留出合适边距
  - **主体区域**：对应时间刻度的横线，作为任务块的容器
  - **红线指示器**：当前时间实线，左端有红点/时间标签，每分钟刷新
- **任务块 (Task Block)**：
  - 悬浮在时间线之上
  - 圆角矩形，根据 `startTime` 和 `duration` 计算高度和 Y 轴位置
  - 颜色区分（支持自定义或继承分类颜色）
- **交互控件**：
  - **左下角悬浮按钮**：📍 "当前时间/回到今天"，点击自动滚动到红线位置
  - **右下角/底部**：➕ 添加新任务

#### 2. 用户确认的交互细节
- **时间网格**：**30分钟一格** (半小时粒度)。
- **调整时间**：
  - **长按主体**：进入拖拽模式，吸附到最近的 30分钟网格。
  - **拖拽边缘**：调整时长 (Duration)，粗略调整。
  - **精确调整**：需点击进入编辑页面，或在创建时输入精确时间。
- **自由度**：允许非整点显示 (如 14:17)，但拖拽操作会吸附网格。
- **自动滚动**：进入页面时，自动滚动到当前时间位置。

#### 3. 数据与逻辑决策 (已确认)
- **存储策略**：**分开存储**。`DailyTask` 独立于 `QuadrantTask`。
- **关联逻辑**：
  - **创建/编辑时**：主动显示 "推荐关联" 区域 (UI预留位置)。
  - **完成同步**：
    - 四象限 Task 完成/取消 → 自动更新 **当天** 和 **昨天** 的关联 DailyTask 状态。
    - **历史保护**：更早日期的 DailyTask 状态不随四象限任务改变，保留历史记录。
    - **单向询问**：未关联的任务完成时，**不弹窗询问**关联，保持干扰最小化。
- **向量计算 (Embedding)**：
  - **当前策略**：先做 UI 和业务逻辑，**预留接口**。
  - **性能预期**：iPhone 12 处理百条数据极快，预计可实时计算。
  - **分批解释**：若数据量达千条，一次性计算会导致 UI 卡顿 (掉帧)。分批是指每帧只算一部分，保持界面流畅。但在本应用体量下暂不需要。

#### 4. 技术概念解释
- **Timer vs Combine**：
  - **Timer**：传统定时器，甚至容易造成内存泄漏如果管理不当。
  - **Combine**：Apple 的响应式框架。这里我们将使用 SwiftUI 原生的 `TimelineView` (系统级优化) 或简单的 `Timer.publish` 来驱动一分钟一次的红线刷新。
- **滑动卡顿问题**：
  - 几百条任务数据量很小，不会卡顿。
  - 关键在于 UI渲染。将使用 `LazyVStack` 或自定义 `Layout`，仅渲染屏幕可见区域，保证丝般顺滑。

#### 5. 实现步骤微调
1. **纯 UI 还原**：实现高度还原 iOS 日历的时间轴和滚动交互（先用假数据）。
2. **数据对接**：实现 `DailyTask` 模型和 SwiftData 存储。
3. **业务逻辑**：增删改查、拖拽吸附算法。
4. **关联系统**：后续接入向量逻辑。


---

## ✅ 最新确定的设计决策 (2026-01-30)

### 1. 数据同步策略
- **全自动同步**：无需弹窗确认
- 四象限任务完成 → 自动同步到今日关联任务
- 今日任务完成 → 根据用户选择同步到四象限任务

### 2. 数据关联关系
- **多对一关系确认**：多个每日任务可以关联同一个四象限任务
  - **典型场景**："修手表"任务跨天未完成，第二天又创建关联任务
  - **特殊场景**："玩游戏" 分多天完成 part1、part2 → **暂未确定处理方案**
- **数据结构**：
  - `DailyTask.linkedQuadrantTaskID: UUID?` (多对一)
  - `QuadrantTask.linkedDailyTaskIDs: [UUID]?` (一对多)

### 3. 向量检索技术方案
- **存储位置**：直接存 SwiftData (SQLite blob)
- **检索范围**：仅未完成任务（预计 ~100 条）
- **性能预期**：无需额外优化，原生方法即可
- **技术选型**：NLEmbedding + Accelerate vDSP
- **不做内存缓存**：数据量小，直接查库即可

---

## 🤔 待讨论的核心问题

### 问题 1：是否真的需要复杂的关联逻辑？

#### 方案对比

| 维度 | 方案 A：复杂关联（当前） | 方案 B：简化版 | 方案 C：延后决策（推荐） |
|------|----------------------|-------------|---------------------|
| **流程** | 创建时预设 → 完成时同步 | 纯时间规划 + 手动完成 | 完成时才决策 |
| **优点** | 体验流畅 | 逻辑简单 | 决策点自然 + 支持灵动岛 |
| **缺点** | 逻辑复杂，边界情况多 | 需要切换页面 | 需要额外弹窗（但精简） |
| **实现难度** | ⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐ |

#### 方案 C 详细设计（推荐）

**核心思路**：把"完成程度"决策延后到完成那一刻

**交互流程**：
1. **创建时**：只关联，不预设完成程度（移除"做一半/做完"选择器）
2. **完成时**：点击任务块上的 ✅ 按钮
3. **弹出快速确认** (Half Sheet)：
   ```
   完成了「写代码」
   
   关联的四象限任务：
   🔴 完成 iOS 开发文档
   
   [✅ 做完了，一起标记完成] ← 高亮
   [📝 只是做了一部分]
   [取消]
   ```
4. **未来扩展**：灵动岛长按 → 同样的快速确认界面

**优势**：
- ✅ 用户不需要提前预测能不能做完
- ✅ 决策点更自然（完成时才需要思考）
- ✅ 避免"做一半"状态的复杂管理
- ✅ 为灵动岛预留接口
- ✅ 逻辑简单：只在完成时判断一次

**需要解决**：
- "玩游戏 part1/part2" 场景：用户可以多次点"做了一部分"，最后点"做完了"

---

### 问题 2：灵动岛集成的复杂度

**用户期望**：
- 显示当前时间段的任务
- 快速完成（点击/长按）
- 不用切换页面

**技术可行性**：
- ✅ Live Activity 支持 (iOS 16.1+)
- ✅ 可以显示当前任务
- ✅ 可以接收点击事件
- ⚠️ 需要 App Intent + Widget Extension

**实施建议**：
- **Phase 2**：完善今日视图基础功能
- **Phase 3**：灵动岛集成（如果采用方案 C，交互设计已经兼容）

---

## 🎯 当前开发状态

### 已完成 ✅
- **DailyView UI**：24 小时时间轴 + 当前时间红线
- **DailyTaskFormView**：创建/编辑任务表单
- **拖拽交互**：移动任务（30分钟吸附）+ 调整时长（15分钟吸附）
- **智能关联 UI**：推荐 → 关联 → 取消关联 (模拟数据)
- **完成程度选择**：创建时预设"做一半/做完"（**可能移除**）

### 待决策 ⚠️
1. **采用哪个方案**：A/B/C？
2. **"玩游戏 part1/part2" 场景**：如何设计数据模型？
3. **完成交互**：在哪里点击完成？（任务块 vs 四象限页面）

### 下一步 📋
- **等待用户确认方案**
- 根据选定方案调整 UI/逻辑
- 实现真实的向量计算 + 关联推荐
- （可选）灵动岛集成

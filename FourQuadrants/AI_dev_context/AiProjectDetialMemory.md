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

## 📅 每日视图 (Daily View) - 设计规划

### 🎨 UI 设计参考
**设计时间**：2026-01-30  
**Mockup**：见 `daily_view_mockup.png`

#### 核心元素
1. **时间轴**（左侧）
   - 24 小时刻度（00:00 - 23:00）
   - 淡灰色文本 + 细分割线
   - 固定宽度约 60pt

2. **任务块区域**（右侧）
   - 按时间段排列的任务卡片
   - 圆角矩形 (cornerRadius: 12)
   - 渐变背景（蓝/紫/粉等）
   - 阴影效果（y: 2, opacity: 0.1）

3. **当前时间指示器**
   - 红色横线贯穿整个视图
   - 左侧显示当前时间标签（如 "14:30"）
   - 使用 Timer 每分钟更新

4. **日期选择器**（顶部）
   - 显示 "January 30, 2026"
   - 左右箭头切换日期
   - 未来可扩展为日历弹窗选择

5. **添加按钮**（底部）
   - 蓝色圆形浮动按钮
   - SF Symbol: "plus"

---

### 📊 数据结构设计

#### DailyTask 模型（新建）
```swift
@Model
class DailyTask {
    // MARK: - 基本信息
    var id: UUID = UUID()
    var title: String
    var date: Date  // 创建日期
    
    // MARK: - 时间规划（核心字段）
    var scheduledDate: Date  // 规划的日期（哪一天）
    var startTime: Date      // 开始时间
    var duration: TimeInterval  // 持续时长（单位：秒）
    
    // MARK: - 状态
    var isCompleted: Bool = false
    var completedAt: Date?
    
    // MARK: - 智能关联
    var linkedTaskID: UUID?  // 关联的 QuadrantTask ID
    var embeddingData: Data?  // NLEmbedding 向量数据
    
    // MARK: - 可选字段
    var notes: String?
    var colorHex: String?  // 任务块颜色（如 "#5E81F4"）
    
    // MARK: - 计算属性
    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }
    
    init(
        title: String,
        scheduledDate: Date,
        startTime: Date,
        duration: TimeInterval = 3600  // 默认 1 小时
    ) {
        self.title = title
        self.date = Date()
        self.scheduledDate = scheduledDate
        self.startTime = startTime
        self.duration = duration
    }
}
```

#### QuadrantTask 扩展（已有模型）
在现有的 `QuadrantTask` 模型中**新增字段**：
```swift
// 反向引用：关联的每日任务
var linkedDailyTaskIDs: [UUID]? = []
```

---

### 🤔 待讨论的技术决策

#### **决策 1：数据存储策略**
- **选项 A**：DailyTask 和 QuadrantTask **分开存储** ⭐️ **推荐**
  - ✅ 逻辑清晰，查询高效
  - ✅ 每日视图只需加载单日 DailyTask
  - ❌ 需要手动维护 `linkedTaskID` 双向引用
  
- **选项 B**：DailyTask 作为 QuadrantTask 的子集
  - ✅ 数据统一，便于全局统计
  - ❌ 查询复杂，耦合度高

**用户确认**：✅ 采用选项 A

---

#### **决策 2：智能关联的触发时机**

**时机 1**：创建每日任务时
- 输入标题 → 后台计算相似度 → 弹出推荐卡片（Top 3）

**时机 2**：完成每日任务时
- ✅ 已关联 → 自动同步完成 `QuadrantTask`
- ❓ 未关联 → **是否询问用户创建关联？**（待定）

**反向问题**：如果用户先完成 `QuadrantTask`，是否同步标记 `DailyTask` 完成？
- **建议**：不同步（因为象限任务是长期规划，每日任务是当天执行）

**用户确认**：待定

---

#### **决策 3：向量计算的性能优化**

**计算时机**：
- **方案 A**：创建/修改任务时 **实时计算** 并存储 ⭐️ **推荐**
  - ✅ 查询时直接读取，无延迟
  - ❌ 写入时有少量开销（约 10-20ms）
  
- **方案 B**：首次搜索时 **懒加载** 并缓存
  - ✅ 写入轻量
  - ❌ 首次搜索会卡顿

**批量匹配策略**（当 QuadrantTask 数量 > 100 时）：
- 使用 `Task.detached` 异步计算
- 分批处理（每批 50 条）
- 显示加载进度（可选）

**用户确认**：✅ 采用方案 A

---

#### **决策 4：UI 交互细节**

**拖拽调整时间**：
- 长按任务块 → 拖拽上下调整开始时间
- 拖拽任务块**下边缘** → 调整时长（类似 iOS 日历）

**时间网格粒度**：
- ❓ **15 分钟一格** vs **30 分钟一格**？（iOS 日历默认 30 分钟）
- ❓ 是否允许自由调整为非整点？（如 14:17 - 15:23）

**当前时间线刷新频率**：
- **建议**：每 1 分钟刷新（使用 `Timer` 或 `TimelineView`）
- 是否需要自动滚动到当前时间？（进入视图时）

**用户确认**：待定

---

#### **决策 5：多日切换逻辑**

**日期选择**：
- 顶部箭头滑动（已设计在 Mockup 中）
- 是否需要日历弹窗快速跳转？（未来扩展）

**数据加载策略**：
- **方案 A**：按需加载单日数据 ⭐️ **推荐**
  - 切换日期时重新查询 SwiftData
  
- **方案 B**：预加载前后 3 天
  - 适合滑动切换动画（未来优化）

**用户确认**：✅ 采用方案 A

---

### 📐 实现阶段规划

#### **Phase 1：基础 UI + 数据模型**（优先级：P0）
- [ ] 创建 `DailyTask` SwiftData 模型
- [ ] 创建 `DailyView.swift` 视图
- [ ] 实现时间轴布局（24 小时刻度）
- [ ] 实现任务块渲染（基于 `startTime` 和 `duration`）
- [ ] 实现当前时间指示器（红色横线 + Timer）
- [ ] 实现日期切换器（顶部箭头）
- [ ] 实现添加任务表单（`DailyTaskFormView`）

#### **Phase 2：拖拽交互**（优先级：P1）
- [ ] 长按拖拽调整开始时间
- [ ] 拖拽边缘调整时长
- [ ] 时间网格吸附（15/30 分钟）
- [ ] 冲突检测（任务时间重叠提示）

#### **Phase 3：智能关联**（优先级：P0）
- [ ] 给 `QuadrantTask` 添加 `embeddingData` 字段（SwiftData Migration）
- [ ] 后台生成所有任务的向量（懒加载）
- [ ] 创建每日任务时，计算相似度并推荐 Top 3
- [ ] 设计推荐卡片 UI（`TaskRecommendationCard`）
- [ ] 实现一键关联功能
- [ ] 完成每日任务 → 自动同步完成关联的 QuadrantTask

#### **Phase 4：体验优化**（优先级：P2）
- [ ] 触感反馈（勾选、拖拽时）
- [ ] 动画过渡（任务块移动、展开/收起）
- [ ] 性能优化（大量任务时的渲染）
- [ ] 多日数据预加载（滑动切换动画）

---

### 🎯 当前状态
- **设计阶段**：✅ UI Mockup 已完成
- **数据结构**：✅ 已规划，待用户确认
- **技术决策**：⚠️ 部分待讨论（见上方"待讨论的技术决策"）
- **下一步**：等待用户确认决策点，开始 Phase 1 实现


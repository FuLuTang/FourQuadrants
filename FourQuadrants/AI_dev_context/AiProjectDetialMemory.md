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

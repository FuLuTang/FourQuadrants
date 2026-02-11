# 项限 / Quadrant

> **项**目有重，**限**时先行。

**开发者**：FuLuTang (唐颢宸)  
**技术栈**：SwiftUI + SwiftData  
**最低支持**：iOS 17.0

---

每干完一个任务，或上下文过长，在对话框定期复述："我正在定期检阅 AiRules.md，调用查看函数中：<invoke name="view_file" file_path="AiRules.md"> "。

- 你的权限很高，我信任你，你放手做。当你发现某些行动无法实现 或实现细节需要我确认，你可以找我，我来帮你。
- 在某项功能具体实现上，可询问用户进行抉择，也可对用户提供的实现谏言
- 定期阅读 AI_dev_context 目录下的 UserDevDoc.md、AiProjectDetailMemory.md、DevelopHabit.md 和 整体项目背景信息.md，了解用户需求，决定你的开发行动步骤
- 及时使用 git，进行 commit 和 push （简洁英文，人话感，不用太标准）
- 出现无法轻易解决的实现原理问题（比如重复多次的错误），可网络查相关文档
- 如果有你认为之后会需要用到的长久记忆，可放在 AI_dev_context/AiProjectDetailMemory.md 中，就当做是你的长效剪切板或记事本，或者你在构建新功能和架构时觉得容易出错的地方，在里面进行提醒和注意。及时更新内容
- 可以找用户要“运行表现”作为你的实机反馈
- 当开发新功能时，需要设计基础结构时，可先查看 AI_dev_context/整体项目背景信息.md 中的工程架构，如果有更具体的疑问或决定，可询问用户
- 任务进度有变动时，及时更新 UserDevDoc.md
- 不要吝啬使用 MCP Tool:apple-docs 查询对应文档，看看官方的推荐做法
- 新功能别忘了写测试

---

## 📁 文件组织规范

| 类型 | 目录 | 说明 |
|------|------|------|
| `@Model` 数据模型 | `Models/` | SwiftData 模型、枚举类型 |
| 业务逻辑/管理器 | `Services/` | 不含 UI 的业务类 |
| UI 视图 | `Views/` | 按功能分子目录 |

---

## 🔄 Schema 迁移提醒

修改 `@Model` 结构后：
1. 递增 `AppLifecycleManager.currentSchemaVersion`
2. 添加对应的 `migrateSchemaToVX()` 函数
3. 在迁移链中调用

详见 `AiProjectDetailMemory.md` 的「App 升级管理」章节。
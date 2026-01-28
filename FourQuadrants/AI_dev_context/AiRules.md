每干完一个任务，或上下文过长，在对话框定期复述："我正在定期检阅 AiRules.md "。

- **🧩 角色身份与多 Agent 协作 (CRITICAL)**：
    - 在对话初始，如果用户指定了你的角色（**Architect** / **Integrator**），你必须立即使用 `view_file` 读取 `AI_dev_context/roles/` 下对应的角色文档。
    - 你必须严格遵守该角色文档中的“权限边界 (Scope of Authority)”。即使你有能力修改 View 层代码，如果你是 Integrator，你也必须拒绝直接修改 UI，而是提供逻辑接口。
    - 在开始工作前，必须查阅 `AI_dev_context/AiPlanMemory.md`，确认是否有队友留下的“模型变更公告”或“跨分支注意事项”。
- 你的权限很高，我信任你，你放手做。当你发现某些行动无法实现 或实现细节需要我确认，你可以找我，我来帮你。
- 在某项功能具体实现上，可询问用户进行抉择，也可对用户提供的实现谏言
- 定期阅读 AI_dev_context 目录下的 UserDevDoc.md、AiPlanMemory.md、DevelopHabit.md 和 整体项目背景信息.md，了解用户需求，决定你的开发行动步骤
- 及时使用git，查看、切换对应的branch，commit，push
- 出现无法轻易解决的实现原理问题（比如重复多次的错误），可网络查相关文档
- 如果有你认为之后会需要用到的长久记忆，可放在 AI_dev_context/AiPlanMemory.md 中，就当做是你的长效剪切板或记事本
- 可以找用户要“运行表现”作为你的实机反馈
- 当开发新功能时，需要设计基础结构时，可先查看 AI_dev_context/整体项目背景信息.md 中的工程架构，如果有更具体的疑问或决定，可询问用户
# macOS 端重构方案

日期：2026-10-28。状态：待用户确认。依据：主对话对 `FourQuadrantsMac/Stickies` 的审阅，以及三份 subagent 只读调研（Mac 主工作区、Mac 依赖的共享层、原版 Stickies 实测）。

## 现状判断

- Mac 端约 4600 行，目录划分（Workspace / Daily / Stickies / Platform）合理，任务写操作基本都经过 `TaskStore`。
- 问题集中在：几处会丢数据或崩溃的 bug、NotificationCenter 充当路由（主窗口关闭后失效）、便笺协调器约一半接口是死代码、大文件职责混杂、约 70 条界面文案没有英文翻译、`docs/Architecture.md` 与 `docs/Persistence.md` 严重过时。
- 测试基线：Mac 测试 17 项，15 过 2 败。

结论：重构成本可控，趁现在做。估计总量约 2000 行搬移拆分、600–800 行新写或改写。

## 分期

每期独立可构建、可测试；每期结束由主对话审查 diff、重跑 Mac 测试（P4 起加跑 iOS 构建），再进入下一期。

### P0 必修 bug（约 120 行，不改结构）

| 问题 | 位置 | 后果 |
| --- | --- | --- |
| 检查器缺少 `.id(task.id)`，切换任务后仍显示旧草稿 | `MacWorkspaceView.swift:87`、`MacTaskInspector.swift` | 保存时把 A 的内容写进 B |
| 便笺窗口未设 `isReleasedWhenClosed = false` | `MacStickyCoordinator.swift:403` | 删除便笺时过度释放，最可能的崩溃根因 |
| `closeAllWindows()` 把所有便笺存成不可见 | `MacStickyCoordinator.swift:126` | 重置后便笺无法恢复 |
| 标题未 trim；分类过滤多出一项 | `updateConfiguration`、两项失败测试 | 测试失败 |
| 日程换日不清空选中 | `MacDailyView.swift:31` | 可对不可见日程执行编辑/删除 |
| 同步合并用 `Dictionary(uniqueKeysWithValues:)` | `SyncService.swift` 约 400 行 | 出现重复链接时直接崩溃 |

完成标准：Mac 测试全绿；崩溃项在 `--preview-data` 下实测创建/删除/关闭循环。

### P1 应用骨架（约 300 行）

- `MacApplicationRuntime` 持有路由状态（显示任务、新建任务、导航），取代 `.macShowTask` / `.macCreateTask` / `.macNavigate` 广播；主窗口关闭时先打开窗口再消费状态。
- 新建 `MacCommands`，App 菜单、菜单栏、工作区共用一份「添加ToDo便笺浮窗」菜单；解决 ⌘N 冲突。
- 共享层加 `TaskCategory.allQuadrants`，删除 7 处手写数组。
- 删除死代码：便笺协调器约 13 个无调用方法、`MacStickiesLibraryView`、`.macNavigate`、未使用的 `@FocusState` 等。

### P2 ToDo便笺重写（约 600 行）

- 协调器拆为：配置存储（防抖写入，去掉每次移动都编码校验）、窗口管理（AppKit 窗口生命周期）、视图。
- `TaskStore` 增加 `task(id:)`、不刷新 `updatedAt` 的置顶接口；便笺不再直接持有 `ModelContainer` fetch。
- 整个标题条非按钮区域可拖动、双击收起；去掉每秒 `TimelineView`，改为只在「完成后短暂显示」到期时刷新。
- 视觉还原放在拿到原版参考之后（见「待定」）。

### P3 主工作区 / 日程 / 设置拆分（约 900 行搬移）

- 抽出 `MacTaskDraft`，检查器与新建表单共用草稿、紧急度与保存逻辑。
- 拆分 `MacDailyView`（527 行）、`MacDailyTaskFormView`（506 行，关键词建议移出视图并加测试）、`MacSettingsView`（484 行）、`MacWorkspaceView`。
- 日程拖拽预览不再写共享 `mainContext`，避免其他窗口保存时把半成品落盘。
- 复用已有 `Color(hex:)` 与日程色板。

### P4 共享层整理（会波及 iOS / Widget，约 300 行）

- 象限映射、完成后可见时长（3 秒）、排序集中到一个纯函数模块，删除 6 处重复。
- `TaskCategory` 拆为纯领域枚举与 UI 扩展。
- `TaskStore` 改用 `didCommit` 回调通知 Widget；`SyncService` 去掉对 Mac 类型的直接引用，改为注入。
- 不拆 `SyncService`（1640 行）：收益不足以抵消风险，另行评估。

### P5 本地化与文档

- 补齐约 70 条 Mac 文案的中英文键值。
- 重写 `docs/Architecture.md`、`docs/Persistence.md`，更新 `docs/macOS-Design.md` 与便笺集成契约。

## 执行方式

- 主对话负责规划、写任务简报、审查 diff 与最终验收；每期的实现交给 Sonnet 5.5（medium）subagent，同期内文件不重叠的任务可并行。
- 每期一个中文提交，正文写明验证情况。

## 待定

1. 是否先为当前未提交的多轮改动做一次基线提交，使重构改动可单独审查。
2. P4 是否纳入本次范围。
3. 原版 Stickies 参考的获取方式：屏幕录制权限被拒，原版当前没有便笺窗口可测。
4. Mac 设置里的「允许任务通知」目前只请求授权、没有任何通知调度：实现它，或先移除开关。

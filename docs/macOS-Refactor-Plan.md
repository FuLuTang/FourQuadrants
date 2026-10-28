# macOS 端重构方案

日期：2026-10-28。

## 状态

- 已完成并提交：P0 `2fb702d`、P1 `f11366d`、P3 `182a985`、P2 `62df77e`。
- P5（Mac 界面本地化补齐、文档重写）已完成，待提交。
- 延后：P4 共享层整理，以及小组件、实时活动相关问题，另行安排。

依据：主对话对 `FourQuadrantsMac/Stickies` 的审阅，以及三份 subagent 只读调研（Mac 主工作区、Mac 依赖的共享层、原版 Stickies 实测）。

## 现状判断

- Mac 端约 4600 行，目录划分（Workspace / Daily / Stickies / Platform）合理，任务写操作基本都经过 `TaskStore`。
- 问题集中在：几处会丢数据或崩溃的 bug、NotificationCenter 充当路由（主窗口关闭后失效）、便笺协调器约一半接口是死代码、大文件职责混杂、约 70 条界面文案没有英文翻译、`docs/Architecture.md` 与 `docs/Persistence.md` 严重过时。
- 重构前测试基线：Mac 测试 17 项，15 过 2 败；P5 完成后 Mac 测试 55 项全部通过。

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

#### 原版 Stickies 实测规格（2026-10-28，用户截图，Retina 2x 换算为 pt）

| 项目 | 原版 | 当前实现 |
| --- | --- | --- |
| 窗口圆角 | 0（直角） | 展开 9pt / 收起 15pt |
| 外边框 | 约 1.5pt 灰 `#B2B2B2`，内侧 0.5pt 浅色高光 `#FEF5A7` | 0.8pt 黑 14% |
| 标题条高度 | 12pt | 29pt |
| 标题条颜色 | 纯色 `#FEEA3D`，顶部 0.5pt 高光 `#FEEC57` | 浅色渐变 |
| 标题条与正文分隔 | 无分隔线，颜色直接过渡 | 0.5pt 黑 10% |
| 正文颜色（黄） | `#FEF49C` | 各象限浅色 |
| 标题条文字 | 无 | 图标 + 分类名 + 箭头 |
| 左侧控件 | 关闭框，8pt 空心方框，深黄 `#DBC400`，距左内边 12pt | 22pt 红色圆角按钮 |
| 右侧控件 | 缩放（斜角）与收起框，各 8pt，间距约 4.5pt，距右内边 12pt | 拖动把手 + 设置菜单 |
| 收起态 | 只剩 12pt 标题条 | 32pt 胶囊 |
| 阴影 | 柔和灰色外阴影 | 8pt 半径阴影 + SwiftUI 内阴影 |

窗口列表中用户已有的收起便笺高度也是 12pt，与截图一致。其他颜色（蓝、绿、粉、紫、灰）尚未实测。

#### P2 设计定稿（2026-10-28）

用户要求：不必百分百还原，要还原原版好用的点——收起后足够小、能浮在最前、像小组件、屏幕利用率高；配色用软件已定义的分类色，不做自定义颜色；手感由设计决定，越简单越好。

窗口
- 使用 `NSPanel`（无边框、`.nonactivatingPanel`、可调整尺寸）。点击便笺勾选任务时不激活本应用、不抢走当前应用的焦点，行为接近小组件。宿主视图 `acceptsFirstMouse` 为真，第一次点击即生效。
- 新建便笺默认置顶（`.floating`），可在右键菜单关闭。
- 直角；1pt 半透明深色描边；使用系统窗口阴影，去掉 SwiftUI 自绘阴影与外边距。
- 默认尺寸：单象限与智能排列 220×260pt，四合一 360×300pt；最小 160×80pt。

标题条（16pt）
- 纯色，比正文深一档；与正文之间无分隔线。
- 左：8pt 空心方框，关闭（隐藏）浮窗。紧随其后：10pt 分类名，点击弹出六模式菜单。
- 右：8pt 收起方框。
- 其余区域全部可拖动；双击任意非控件区域切换收起。右键标题条弹出完整菜单：六模式、显示详情、置顶、删除浮窗配置。去掉设置按钮与中间把手。
- 收起后只剩标题条，宽度、横向位置、上边界不变；无动画，立即切换。收起态分类名后显示未完成数量（如「重要且紧急 · 3」）。

配色
- 四个象限：`AppTheme.Colors` 的四个分类色，正文用浅色调、标题条用深一档的浅色调；四合一与智能排列用原版 Stickies 黄（正文 `#FEF49C`、标题条 `#FEEA3D`）。纸张不随深色模式变化，文字始终深色。
- 删除 `MacStickyPaper` 的用户可选颜色与 `opacity` 设置；旧配置中的多余字段解码时忽略。

内容
- 紧凑任务行：12pt 标题，勾选圈 12pt，行高约 20pt，行与行之间不加色块背景。双击行或右键「在主窗口中打开」。去掉行尾省略号菜单。
- 四合一为 2×2，每格 14pt 小标题（象限名 + 数量），格间 1pt 分隔线。
- 去掉每秒 `TimelineView`；刚完成的任务只在 3 秒到期时触发一次刷新。

结构
- 协调器只负责配置与对外接口；配置存储防抖写入；AppKit 面板控制器负责窗口生命周期与几何；SwiftUI 只负责内容。
- `TaskStore` 新增 `task(id:)`，便笺不再直接 fetch `ModelContainer`。

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

## 用户决定（2026-10-28）

1. 范围：只做 Mac 部分（P0–P3、P5）。P4 及小组件、实时活动相关问题之后单独修。共享层只做 Mac 必需的新增接口（如 `TaskStore.task(id:)`、`TaskCategory.allQuadrants`）和与小组件无关的同步崩溃修复。
2. 已做基线提交 `0667827`；重构每期单独提交。
3. 视觉参考：用户开启屏幕录制权限，由 Claude 在原版 Stickies 新建一张空白便笺测量，测完删除。
4. 移除 Mac 设置中无实际作用的「允许任务通知」开关（放入 P1）。

## 遗留事项

### 共享层硬编码中文（P5 未处理）

这些文案位于 iOS 与 Mac 共用的代码中，本期按约定不改：

- `TaskStore`：`lastErrorMessage = "保存失败，请重试。"`。
- `PersistenceController`：`PersistenceError` 的三条 `errorDescription` 与「无法访问当前应用的 Application Support 目录。」。
- `SyncService` 中的用户可见错误文案（`userFacingError` 等）。
- Mac 界面里 `AppDataController` 恢复界面展示的上述错误，因此英文界面下仍会出现中文。
- `strings` 文件中仍有若干早期遗留、代码未使用的键（如 `手选任务 · %d 项`、`纸张透明度 %d%%`），未清理。

### P4 共享层整理（延后）

- 象限映射、完成后可见时长、排序集中到纯函数模块，删除重复。
- `TaskCategory` 拆为纯领域枚举与 UI 扩展。
- `TaskStore` 与 `SyncService` 解耦 Mac 类型、改为注入；不拆 `SyncService`。
- 小组件与实时活动相关问题。

### 需人工验收的交互

自动化测试与截图无法覆盖，需要在真机交互中确认：

- 便笺：拖动、调整大小、双击收起/展开、右键菜单、点击勾选不抢焦点、置顶、隐藏后恢复、重启后恢复位置。
- 主窗口：拖动任务换象限、检查器编辑后保存、菜单栏与 ⌘N、关闭主窗口后从菜单栏重新打开。
- 日程：点击空白新建、拖动与调整时长、重叠布局、关联任务。
- 同步：Microsoft 登录、首次合并、诊断（需要真实账户与已登记的重定向 URI）。
- 英文界面下的 tooltip（`help`）与辅助功能标签；ternary 形式的本地化按钮标题。
- 浅色/深色与最小窗口下的文字截断。

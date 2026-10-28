# macOS ToDo便笺与原版 Stickies 窗口还原交接

交接日期：2026-10-28。工作目录：`/Users/tanghaochen0506/Documents/Xcode/FourQuadrants`。

本文记录进行中的实现、用户已确定的产品要求和后续验收入口。当前窗口还原尚未通过实际截图与鼠标操作验收。2026-10-28 本轮只整理交接并核查源码与 Git 状态，没有重新构建、测试或修改产品代码。

## 1. 接手后首先确认的方向

用户要尽量还原 **Apple 原版 Stickies 的窗口外观与交互**，内容区展示项目中的 ToDo list。用户已授权尝试实现；下一步可继续实现与验收。

**前轮存在视觉方向偏差，需要优先纠正：** 用户的对比图中，左侧是本项目较厚的浅色圆角控制条，右侧黄色、极薄、近直角的标题窄条才是原版 Stickies 参照。前轮继续强化了胶囊圆角和浅色渐变，并将这些描述成接近目标；这个判断没有得到截图验证。接手时应重新看原图或直接观察本机 Stickies，再决定标题栏的厚度、边框、按钮、颜色和圆角。

当前代码里的新建宽度 195pt、折叠高度 32pt、折叠圆角 15pt、浅色渐变均为前轮尝试值。用户没有指定这些数值，也没有验收它们。用户曾明确指出现有窗口比原版厚、拖不动、关闭和删除存在问题；这些操作仍需实际复测。

用户对收起行为的明确描述是：**窗口宽度、横向位置和上边界保持不变，仅下边界向上移动；双击切换展开与收起。** 拖动收起态之后，再展开应沿用移动后的顶部位置，并恢复原来的展开尺寸。

## 2. 用户确定的产品要求

- 名称统一用“ToDo便笺”。内容展示已有任务列表，支持勾选；不提供自由文本便笺编辑。
- 共六种模式：四个象限各一种、四合一、智能排列。四合一平分为四块，各自展示任务；智能排列可参考项目已有 iOS 小组件。
- 四象限使用不同背景色；支持置顶、展示详情等参数。
- 在主页四象限视图提供“添加ToDo便笺浮窗”入口。无需专门的便笺管理页面。
- 点击便笺标题选择分类；窗口可拖动、可关闭、可收起、可调整尺寸。
- 关闭窗口只隐藏它；删除便笺配置只移除该浮窗，不删除任务。
- 支持后台运行：关闭主窗口后应用继续运行，Mac 顶部菜单栏有应用入口。用户授权设计菜单选项。
- 最初报告的故障：在主窗口删除便笺会卡死；浮窗关闭按钮无法点击；浮窗拖不动。截图显示 `objc_release` 上的 `EXC_BAD_ACCESS`，仅凭截图不能确定完整根因。

## 3. 参考资料范围与已知结论

用户要求从其提供的“Stickies 原版逆向及仿品”范围内寻找参考。不要继续引入 Tic 或其他未经用户认可的便笺项目。Swift 工程可使用 Objective-C/AppKit；旧代码年代本身不构成排除理由。评价是否相似时必须查看实际界面。

以下是之前已查看资料的结论；2026-10-28 没有重新在线核对仓库内容。

| 资料 | 用途与证据边界 |
| --- | --- |
| [StickerColorPicker](https://github.com/shishkabibal/StickerColorPicker) | 主参考。插件项目中保存原版 Stickies 的 class-dump 头文件，可用来理解对象结构与交互入口。插件以注入/swizzling 修改原版颜色；这些头文件没有 Apple 方法实现，无法直接复制出原版窗口。 |
| [SNWindow.h](https://github.com/shishkabibal/StickerColorPicker/blob/main/StickerColorPicker/SNWindow.h) | 可见 spine/title、关闭/缩放/折叠控件、展开矩形、floating/translucent、拖动与 key-window 生命周期等声明。 |
| [SNSpineView.h](https://github.com/shishkabibal/StickerColorPicker/blob/main/StickerColorPicker/SNSpineView.h) | 独立 `NSView` 与 `mouseDown:` 声明，可用于标题脊线的交互分层参考。 |
| [SNWindowControlButtonCell.h](https://github.com/shishkabibal/StickerColorPicker/blob/main/StickerColorPicker/SNWindowControlButtonCell.h) | `NSButtonCell` 与 `drawWithFrame:inView:` 声明，可参考自绘窗口按钮的职责分层。 |
| [SNDocument.h](https://github.com/shishkabibal/StickerColorPicker/blob/main/StickerColorPicker/SNDocument.h) | UUID、窗口、颜色组、日期与文档状态等结构参考。保留本项目任务模型与本地浮窗配置。 |
| [ModernStickies](https://github.com/AlexDenisov/ModernStickies)、[原作者文章](https://lowlevelbits.org/reverse-engineering-stickies.app/) | 之前核对到的实际实现主要是逆向/修改颜色数据与二进制 patch。不能据此声称已获得折叠、拖动、关闭的完整实现。 |
| [stick-notes](https://github.com/omanoloneto/stick-notes) | 可参考原生窗口、多窗口与持久化组织。已看过 `docs/themes.png` 和主题实现，界面与用户的原版参照相差明显；用户也认可它不像，不能把它作为视觉目标。 |

用户此前还列出 Infinite Mac 的 `stickies.py`、pystickies、python-typedstream；这些重点涉及旧便笺数据格式，与当前窗口还原的直接关系较小。无需为此重新扩张调研。

原版行为的具体尺寸与绘制细节需要从原图、本机原版窗口或有证据的实现观察获得。涉及第三方代码复制时保留适用许可；仓库许可不能自动解释为 Apple 私有实现的许可。当前工程应保持独立运行的原生窗口。

## 4. Git 状态与工作边界

2026-10-28 核查：

- 分支：`codex/macos-desktop-workspace`。
- HEAD：`2fac902 完善 iOS 小组件布局与任务交互`。
- 工作树含大量既有修改和未跟踪文件，覆盖同步、数据模型、iOS、Widget、Mac、工程配置等。本轮没有提交。
- ToDo便笺相关代码及更早的大范围 Mac 改造仍处于未提交状态；`git diff HEAD` 同时包含多轮工作，不能将整个 diff 归给最后一次还原。
- 保留现有改动。接手时先检查最新状态，再限制文件与 hunk 范围。需要提交时按用户要求使用中文标题与简洁中文正文，并明确验证情况。
- `MSALConfig.swift`、Mac `Info.plist` 等还有其他会话的修改；不要为窗口还原顺带覆盖它们。

原生 Mac scheme 是 `FourQuadrantsMac`。最初截图中的 iOS scheme 显示 `My Mac (mismatched platform)`，不能用于判断原生 Mac target 不存在。保留原生 Mac target；运行与验收应选择该 scheme。

## 5. 代码导航与当前实现

| 文件 | 当前职责 |
| --- | --- |
| [FourQuadrantsMacApp.swift](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/FourQuadrantsMac/FourQuadrantsMacApp.swift) | 主场景、应用菜单、ToDo便笺命令、`MenuBarExtra` 与关闭最后窗口后的运行策略。 |
| [MacApplicationRuntime.swift](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/FourQuadrantsMac/MacApplicationRuntime.swift) | 共享数据会话、`TaskStore`、便笺协调器、启动恢复和应用退出清理；支持隔离的 `--preview-data` 模式。 |
| [MacWorkspaceView.swift](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/FourQuadrantsMac/Workspace/MacWorkspaceView.swift) | 主工作区及创建/展示浮窗入口、任务路由。 |
| [MacStickyConfiguration.swift](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/FourQuadrantsMac/Stickies/MacStickyConfiguration.swift) | Codable 模式、纸色、展开态矩形及显示参数；`MacStickyWindowFrame.collapsed(to:)` 负责顶部锚定变换。 |
| [MacStickyCoordinator.swift](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/FourQuadrantsMac/Stickies/MacStickyCoordinator.swift) | 浮窗创建、隐藏、移除、参数更新、任务过滤与持久化；同文件内有私有 `MacStickyWindow` 和 `MacStickyWindowController`。 |
| [MacStickyViews.swift](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/FourQuadrantsMac/Stickies/MacStickyViews.swift) | SwiftUI 标题条、六模式选择、任务列表、四合一、设置菜单；中心拖动把手通过 `NSViewRepresentable` 接 AppKit 鼠标事件。 |
| [MacStickyConfigurationTests.swift](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/FourQuadrantsMacTests/MacStickyConfigurationTests.swift) | 配置编解码、任务过滤、删除持久化与顶部锚定几何测试。 |
| [IntegrationContract.md](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/FourQuadrantsMac/Stickies/IntegrationContract.md) | 当前窗口与宿主应用的集成契约。 |
| [macOS-Design.md](/Users/tanghaochen0506/Documents/Xcode/FourQuadrants/docs/macOS-Design.md) | Mac 模块所有权、产品不变量及验收清单。 |

### 数据与生命周期

- UI 使用 AppKit `NSWindow` + SwiftUI `NSHostingView`。窗口为自定义无边框、透明背景，可成为 key/main window。
- 任务沿用共享 SwiftData 模型；勾选通过同一个 `TaskStore` 修改。浮窗配置另存 `UserDefaults`，key 为 `FourQuadrants.macStickies.configurations.v1`，不增加任务数据库 schema。
- `hideWindow` 用于隐藏；移除配置会从协调器的窗口表删除控制器，并调用 `schedulePermanentClose()`。永久清理通过主队列延后，依次解除 delegate、移除 contentView、关闭窗口。这个处理已写入源码，原始崩溃的运行时回归仍未完成。
- 应用启动恢复可见浮窗，退出时关闭窗口。主窗口关闭后继续运行，通过菜单栏重新打开主窗口或浮窗。
- 历史手选任务模式仍存在于 Codable 与兼容方法中；用户面对的产品入口为六种 ToDo 模式。

### 最近一次窗口实现尝试

- 默认新建矩形为 `(x: 180, y: 620, width: 195, height: 330)`；四合一最小宽度 420pt。已有配置保留保存的尺寸。
- 收起高度 32pt，标题内容区高度 29pt；展开态圆角 9pt，收起态圆角 15pt。
- 收起用 `y + expandedHeight - compactHeight` 计算底部坐标，保留 `x`、宽度与 `maxY`；展开恢复 `expandedFrame`。已经去掉展开时额外强制 220pt 宽、190pt 高的旧逻辑。
- 收起态移除 `.resizable`；展开态恢复。收起态拖动会平移保存的展开矩形。
- `NSAnimationContext` 用 0.2 秒做窗口 frame 动画；`isChangingCollapsedState` 在动画期间抑制保存中间矩形，完成回调通过 `Task { @MainActor ... }` 恢复并保存。
- **拖动与双击目前仅在中心把手区域生效**。标题按钮弹出六模式菜单；关闭和设置有各自命中区域。整个非按钮标题区域的交互尚未完成。
- `configuration.opacity` 已连接 `NSWindow.alphaValue`；置顶连接 `.floating` / `.normal`。
- 每秒 `TimelineView` 更新可见任务；若继续排查能耗、卡死或频繁刷新，应检查它与窗口 frame 持久化的交互，但当前没有证据将其认定为原始崩溃根因。

## 6. 仍待完成的工作与已知风险

1. **重新建立视觉基准。** 实测原版收起条高度、边框、按钮与激活/失焦效果；先确认对比图的两侧归属。不要将现有胶囊样式写成已验收结果。截图本身的物理像素应结合 Retina 缩放换算，195pt 不能当作测量结论。
2. **关闭与删除回归。** 实际点击浮窗关闭、主窗口移除浮窗、浮窗菜单移除配置，重复创建/关闭/恢复。观察所有权、delegate 回调和 SwiftUI 销毁是否还出现卡死或 `EXC_BAD_ACCESS`；必要时使用 Zombies/Address Sanitizer 与完整调用栈。
3. **拖动与双击命中范围。** 在按钮仍可点击的前提下，把原版要求的非按钮标题区域做成可靠拖动/双击区域；当前细小中心把手仍是交互差距。
4. **展开/收起完整生命周期。** 覆盖移动后展开、重启恢复、多个窗口、显示器边缘、改尺寸后收起，以及动画中再次操作。现有单元测试只验证纯几何变换，无法证明这些运行时行为。
5. **模式切换尺寸一致性。** `ensureMinimumExpandedWidth` 在切到四合一时会扩大保存的展开宽度；收起态当下的可见宽度可能继续沿用旧值。需确认用户感知与顶部/左侧锚定规则。
6. **六模式与任务互动。** 核对四象限色、四合一任务归属、智能排序、直接勾选及短暂完成显示、展示详情与置顶。原有截图中的空列表不能当作任务展示验收。
7. **后台菜单验收。** 主窗口关闭后应仍能通过菜单栏新建任务、打开四象限、创建/恢复浮窗、打开设置和退出；Dock 重开与真实退出恢复也要实测。
8. **两项历史失败测试。** 见下一节。它们在最后一次完整测试中失败，不能将完整测试报告为通过；此前没有在干净基线重跑来证明其最初引入时间。
9. **数据会话重置与契约。** `MacApplicationRuntime.reset()` 也调用 `closeAllWindows()`；集成契约目前写成仅应用终止时调用。接手时应检查重置路径的窗口清理与重新恢复，并让代码与契约表达一致。

## 7. 验证证据与重跑方法

以下结果来自 **2026-10-03**，非本次交接的重新验证：

- Mac Debug 构建通过，关闭签名校验：`BUILD_EXIT=0`。
- 新增几何测试单独执行，结果为 1 passed / 0 failed，已用 `xcresulttool` 核对实际执行数。
- 全部 Mac 单元测试为 17 项：15 passed / 2 failed。
- `git diff --check` 当时通过。
- 没有实际启动应用完成截图与鼠标验收；没有证明原始删除崩溃、关闭失效已经修复。

两项失败：

| 测试 | 当时实际失败内容 |
| --- | --- |
| `categoryNotesReturnTheMatchingVisibleTasksForEveryCategory()` | 某分类的实际任务 ID 集合比预期多一项，需要追踪分类与完成任务保留规则。 |
| `updatingConfigurationSettingsPersistsNormalizedValues()` | 期望标题 `新标题`，实际保留两端空格 `  新标题  `。当时 `updateConfiguration` 的非空分支仍保存原始 `title`。 |

旧结果位于 `/tmp/FourQuadrantsTodoStickiesFinal` 与 `/tmp/FourQuadrantsTodoStickiesFocused`；2026-10-28 已未找到这两个目录中的测试日志，不依赖这些临时文件接手。

从仓库目录执行；可另选独立 DerivedData 路径：

```sh
cd /Users/tanghaochen0506/Documents/Xcode/FourQuadrants
xcodebuild -quiet -project FourQuadrants.xcodeproj \
  -scheme FourQuadrantsMac -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/FourQuadrantsTodoHandoffDerived \
  CODE_SIGNING_ALLOWED=NO build
```

```sh
xcodebuild -quiet -project FourQuadrants.xcodeproj \
  -scheme FourQuadrantsMac -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/FourQuadrantsTodoHandoffDerived \
  CODE_SIGNING_ALLOWED=NO test \
  '-only-testing:FourQuadrantsMacTests/MacStickyConfigurationTests/collapsingPreservesHorizontalGeometryAndAnchorsToTopEdge()'
```

完整测试移除 `-only-testing`。Swift Testing 的筛选名称必须使用实际函数名并保留 `()`；之前误加 `test` 前缀会得到退出码 0、实际执行 0 项的无效验证。需要用结果包核对测试数量。

签名关闭的构建只证明源码可构建。之前启用签名的构建遇到 provisioning profile 缺失；应区分签名环境与源码错误。实际启动可使用 Xcode 的原生 Mac scheme；`--preview-data` 提供独立内存数据和便笺偏好，适合不接触真实账户与任务的 UI 验收。

## 8. 接手建议与协作要求

先用原版与当前应用的实际窗口做并排截图，确认目标、测量尺寸和手势；随后修复标题条与交互命中，完成关闭/删除稳定性回归，最后验证六模式和后台菜单。保留对应截图与明确的验收结果，再报告还原程度。

用户要求主对话集中于设计、架构、决策与感知验证，重复检索和细节审阅尽量交给真实 subagent。Luna 可用于检索、细节核对与有清晰范围的实现。不要通过新建可见聊天、分支任务或 worktree 冒充 subagent。给 subagent 的提示中加入“出现分歧优先询问并直接结束句子”，方便主 agent 决策。

用户另有明确语言限制：保持直述，避免先否定再转折的固定句式。不要先凭项目名称、描述或代码年代判定外观是否相似；先看图和行为。报告中区分源码状态、构建、单元测试与真实窗口验收。

用户原图附在本次对话早期消息中：两组蓝/黄与浅色胶囊/黄色窄条对比，以及 `objc_release` 崩溃截图。原附件位于 macOS 临时目录，路径可能已失效；应优先从对话恢复图像或观察本机原版。不要用手工生成的示意图替代运行时截图作为还原证据。

# macOS ToDo便笺 集成契约

## 宿主职责

宿主 App 持有生命周期与依赖注入：构造一个 `MacStickyCoordinator(container:taskStore:defaults:)`，通过 `.environment(coordinator)` 注入工作区，数据就绪后调用 `restoreWindows()`，应用退出时调用 `closeAllWindows()`。浮窗打开期间协调器必须保持存活；只关闭主窗口时 App 不应退出。

便笺请求「在主窗口中打开某任务」时调用 `coordinator.onOpenTask`（由 `MacApplicationRuntime` 注入，转为 `requestShowTask`）。协调器不依赖 runtime 类型，也不校验任务是否存在，由主窗口路由处理。

## 分层

- `MacStickyCoordinator`：只管配置与对外接口（创建、显示/隐藏、删除、切换内容来源、置顶、显示详情、收起），并保存窗口位置。
- `MacStickyConfigurationStore`：UserDefaults 存储。结构性修改立即写入；拖动、缩放产生的位置变化经 0.4 秒防抖再写，不会每个事件都编码。`flush()` 立即落盘，协调器在 `closeAllWindows()` 与 `NSApplication.willTerminateNotification` 时自动调用。存档无法识别时保持只读并保留原始数据。
- `MacStickyPanelController`：每张便笺一个 `NSPanel`，负责创建、显示、层级、可调整尺寸与框架，以及把窗口移动/缩放回报给协调器。
- `MacStickyViews` / `MacStickyMenu`：SwiftUI 内容与 AppKit 菜单。内容通过 `.modelContainer` 用 `@Query` 读取任务，不经协调器 fetch。

## 窗口行为

- `NSPanel`，无边框、`.nonactivatingPanel`、可调整尺寸；点击便笺不激活本应用。宿主视图 `acceptsFirstMouse` 为真。`hidesOnDeactivate` 为假。
- 新建便笺默认置顶（`.floating`），右键菜单可关闭（`.normal`）。直角，1pt 半透明描边，系统阴影。
- 默认尺寸：单象限与智能排列 220×260pt，四合一 360×300pt；最小 160×80pt。新建时在主屏可见区域左上角附近按数量错开 24pt。
- 标题条 16pt：左侧 8pt 空心方框隐藏浮窗，其后 10pt 分类名（点击弹六模式菜单），右侧 8pt 方框收起/展开。其余区域可拖动，双击切换收起，右键弹出完整菜单（六模式、显示任务详情、保持在其他窗口上方、删除此浮窗配置）。
- 收起态只剩标题条（16pt 高），分类名后显示未完成数量；宽度、左边界、上边界不变；无动画。收起/展开不改变保存的展开态框架。

## 配置与几何

配置存放在 `UserDefaults`（键 `FourQuadrants.macStickies.configurations.v1`），不改 SwiftData schema。字段：`id`、`source`、`frame`（展开态框架）、`isCollapsed`、`isVisible`、`isFloating`、`showDetails`。旧存档中的 `title`、`paper`、`opacity` 等字段解码时忽略，缺失字段取默认值；`selectedTaskIDs` 来源仍可解码，显示时按智能排列处理。

- 收起：窗口框架由展开态框架推导（左边界、宽度、上边界不变，只有下边界上移）。拖动收起态窗口会更新展开态框架的位置，再展开时使用移动后的上边界。
- 切换到四合一时宽度不足 320pt 则向右扩展（左边界不变），收起态同理。
- 删除浮窗配置只删除本地显示偏好，不删除任何任务。
- 配色：四个象限取 `AppTheme.Colors` 四色的浅色调（标题条深一档）；四合一与智能排列用 Stickies 黄（正文 `#FEF49C`、标题条 `#FEEA3D`）。纸张不随深色模式变化。
- 刚完成的任务显示 3 秒（`TaskStore.completionVisibilityDuration`），到期时刷新一次，没有逐秒刷新。

## 调试

Debug 构建下 `--preview-data --preview-stickies` 会清空预览配置并创建单象限、四合一、收起态各一张便笺，用于截图验收。

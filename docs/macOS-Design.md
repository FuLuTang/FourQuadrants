# macOS 界面与实现边界

## 目标

原生 macOS 应用包含四象限、任务列表、已完成、新建与详情编辑、日程及其编辑、设置、Microsoft 同步状态/首次合并/诊断、数据恢复和独立的 ToDo便笺浮窗。主窗口支持集中规划；浮窗持续展示任务清单并允许直接勾选。

## 模块所有权

- `FourQuadrantsMacApp` / `MacApplicationRuntime` / `MacCommands` / `MacPreviewData`：一个应用数据会话、窗口生命周期、路由状态（显示任务、新建任务）、菜单命令、依赖注入。
- `Workspace`：主窗口（`MacWorkspaceView`、侧栏、工具栏、内容路由）、四象限看板、任务列表与行、检查器、新建/编辑表单与共用草稿 `MacTaskDraft`、设置（外观、同步、关于）、同步状态与诊断、首次合并、数据恢复。
- `Daily`：日程视图、时间轴（布局、拖拽数学、当前时间线）、日程表单、关联任务选择与关键词建议。
- `Stickies`：ToDo便笺。协调器管配置与对外接口，`MacStickyConfigurationStore` 管 UserDefaults 存储，`MacStickyPanelController` 管 `NSPanel`，`MacStickyViews` / `MacStickyMenu` 管内容与菜单。详见 `FourQuadrantsMac/Stickies/IntegrationContract.md`。
- `Platform`：系统适配（MSAL 认证窗口）。共享 `Models`、`TaskStore` 与同步服务保持统一业务规则。

## 不变量

1. 同一任务在所有窗口引用同一数据模型，所有任务修改经过 `TaskStore`。
2. ToDo便笺只展示现有任务，不提供自由文本编辑；四个象限、四合一、智能排列共六种模式。便笺是 `NSPanel`：无边框、不激活应用、默认置顶，16pt 标题条（左侧隐藏、分类名菜单、右侧收起）。
3. 关闭浮窗只隐藏窗口。移除浮窗配置不会删除任务。
4. 窗口位置、尺寸、置顶、展示详情属于 Mac 本地显示配置，与跨设备任务同步分开。
5. 主窗口关闭后应用继续运行；退出应用后所有窗口消失，下次启动恢复已显示便笺。
6. 原生 Mac 界面通过键盘、鼠标和菜单工作，不依赖触控长按。
7. 现有 `DailyTask` 与 `QuadrantTask` 关系保持不变；日程跨设备同步不因新增 target 自动获得。
8. `--preview-data` 使用独立内存数据库与独立便笺偏好，不连接账户、不操作用户任务。

## Microsoft 登录配置

- Mac Debug bundle ID：`com.fulu.FourQuadrants.macOS.dev`；复用 iOS Debug redirect URI：`msauth.com.fulu.FourQuadrants.dev://auth`。
- Mac Release bundle ID：`com.fulu.FourQuadrants.macOS`；复用 iOS Release redirect URI：`msauth.com.fulu.FourQuadrants://auth`。
- Mac bundle ID 保持独立，用于 Mac 应用身份与 Keychain；Microsoft 登录回调复用对应 iOS 环境的 URI。对应 URI 必须已登记在此客户端的 Microsoft Entra 应用注册中；当前仓库未连接或检查该注册配置。
- macOS MSAL 交互流由系统认证会话处理回调；应用 URL handler 保留用于 `fourquadrants://task/...` 任务链接。

## 验收清单

- Mac target 构建；共享层变更后 iOS 构建回归。
- 主窗口：四象限、列表、已完成、搜索、排序、详情、新建、完成/恢复、删除、拖动分类。
- 日程：日期导航、空状态、新建、编辑、关联任务、完成、移动/调整时长、重叠布局。
- 设置：外观、通知、关于、同步未连接/连接状态、首次合并和诊断界面。
- ToDo便笺：从主窗口工具栏、菜单栏与「ToDo便笺」菜单创建六种浮窗；点击分类名切换模式、右键标题条菜单（六模式、显示任务详情、保持在其他窗口上方、删除此浮窗配置）；点击便笺勾选任务时不抢走其他应用的焦点；双击标题条收起/展开（宽度、左边界、上边界不变，收起态显示未完成数量）；拖动、调整大小、隐藏与恢复、置顶开关；配置在重启后恢复；便笺使用象限色与 Stickies 黄，不随深色模式变化。
- 多窗口同一数据一致性；重复打开不会无意创建多份任务。
- 浅色/深色、最小窗口、中文与英文文字截断和键盘可达性；`-AppleLanguages '(en)'` 下无残留中文（示例任务除外）。
- 实际运行截图与交互验证；未实测的登录、跨设备行为单独列出。

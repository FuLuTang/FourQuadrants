# macOS 界面与实现边界

## 目标

原生 macOS 应用包含四象限、任务列表、已完成、新建与详情编辑、日程及其编辑、设置、Microsoft 同步状态/首次合并/诊断、数据恢复和独立的 ToDo便笺浮窗。主窗口支持集中规划；浮窗持续展示任务清单并允许直接勾选。

## 模块所有权

- `FourQuadrantsMac/Workspace`：主工作区、任务编辑、设置与恢复。
- `FourQuadrantsMac/Daily`：鼠标驱动日程、日期导航、时间块和日程编辑。
- `FourQuadrantsMac/Stickies`：ToDo便笺的展示模式、配置存储与独立窗口。
- `FourQuadrantsMac/Platform`：系统适配；共享 `Models`、`TaskStore` 与同步服务保持统一业务规则。
- `FourQuadrantsMacApp` / `MacApplicationRuntime`：一个应用数据会话、窗口生命周期和依赖注入。

## 不变量

1. 同一任务在所有窗口引用同一数据模型，所有任务修改经过 `TaskStore`。
2. ToDo便笺只展示现有任务，不提供自由文本编辑；四个象限、四合一、智能排列共六种模式。
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
- ToDo便笺：从四象限主页创建六种浮窗；标题切换模式；分类背景色、任务勾选、展示详情、折叠、拖动、置顶、关闭与恢复、配置持久化。
- 多窗口同一数据一致性；重复打开不会无意创建多份任务。
- 浅色/深色、最小窗口、中文文字截断和键盘可达性。
- 实际运行截图与交互验证；未实测的登录、跨设备行为单独列出。

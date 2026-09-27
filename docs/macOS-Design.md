# macOS 界面与实现边界

## 目标

原生 macOS 应用包含四象限、任务列表、已完成、新建与详情编辑、日程及其编辑、设置、Microsoft 同步状态/首次合并/诊断、数据恢复、便笺管理和独立桌面便笺。主窗口支持集中规划，便笺支持持续可见的任务执行。

## 模块所有权

- `FourQuadrantsMac/Workspace`：主工作区、任务编辑、设置与恢复。
- `FourQuadrantsMac/Daily`：鼠标驱动日程、日期导航、时间块和日程编辑。
- `FourQuadrantsMac/Stickies`：便笺定义、配置存储、独立窗口及管理页面。
- `FourQuadrantsMac/Platform`：系统适配；共享 `Models`、`TaskStore` 与同步服务保持统一业务规则。
- `FourQuadrantsMacApp` / `MacApplicationRuntime`：一个应用数据会话、窗口生命周期和依赖注入。

## 不变量

1. 同一任务在所有窗口引用同一数据模型，所有任务修改经过 `TaskStore`。
2. 便笺仅保存任务 ID 或筛选条件；便笺成员关系不改变任务象限或原有置顶排序。
3. 关闭便笺只收起窗口。移除便笺配置不会删除任务。
4. 窗口位置/尺寸/颜色属于 Mac 本地显示配置，与跨设备任务同步分开。
5. 主窗口关闭后应用继续运行；退出应用后所有窗口消失，下次启动恢复已显示便笺。
6. 原生 Mac 界面通过键盘、鼠标和菜单工作，不依赖触控长按。
7. 现有 `DailyTask` 与 `QuadrantTask` 关系保持不变；日程跨设备同步不因新增 target 自动获得。
8. `--preview-data` 使用独立内存数据库与独立便笺偏好，不连接账户、不操作用户任务。

## Microsoft 登录配置

- Mac Debug bundle ID：`com.fulu.FourQuadrants.macOS.dev`；redirect URI：`msauth.com.fulu.FourQuadrants.macOS.dev://auth`。
- Mac Release bundle ID：`com.fulu.FourQuadrants.macOS`；redirect URI：`msauth.com.fulu.FourQuadrants.macOS://auth`。
- 两个新增 redirect URI 需由 Microsoft Entra 应用注册的账号拥有者登记后，才可完成真实账号登录验收；当前仓库未连接或检查该注册配置。
- macOS MSAL 交互流由系统认证会话处理回调；应用 URL handler 保留用于 `fourquadrants://task/...` 任务链接。

## 验收清单

- Mac target 构建；共享层变更后 iOS 构建回归。
- 主窗口：四象限、列表、已完成、搜索、排序、详情、新建、完成/恢复、删除、拖动分类。
- 日程：日期导航、空状态、新建、编辑、关联任务、完成、移动/调整时长、重叠布局。
- 设置：外观、通知、关于、同步未连接/连接状态、首次合并和诊断界面。
- 便笺：手选/动态来源、创建、独立窗口、完成任务、编辑成员、颜色、折叠、置顶、收起/恢复、配置持久化。
- 多窗口同一数据一致性；重复打开不会无意创建多份任务。
- 浅色/深色、最小窗口、中文文字截断和键盘可达性。
- 实际运行截图与交互验证；未实测的登录、跨设备行为单独列出。

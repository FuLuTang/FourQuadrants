# Microsoft To Do 兼容层：保留全量，操作增量

## 总目标

Microsoft To Do 是任务的基础系统，也是重复、提醒与精确到期时间语义的所有者。Four Quadrants 是可靠的同步视图和四象限增强层。同步绝不以本地快照全量覆盖远端；未知或尚未支持的 Microsoft 字段必须被保留，日常操作只 PATCH 用户实际改动的字段。

Four Quadrants 不创建或编辑重复规则，也不实现跳过本次、延期一轮、按完成日期滚动等生命周期逻辑。完成当前任务后出现何种下一轮，由 Microsoft To Do 与其 delta 返回结果决定。

## 持久化基线

当前只定义一个 `AppSchemaV1`，它包含本次 bridge 影子字段在内的完整首发模型。V1、V2、V3、V4 都从未对外发布；此前开发构建创建的本地 SwiftData 数据库不在迁移支持范围内，测试或开发设备可重置本地数据后使用该首发基线。正式发布后，任何 schema 变化都必须以固定历史快照和迁移计划演进。

## 本次目标

- 将 Graph `recurrence` 以原始 JSON 保存到 `MicrosoftTodoTaskLink`，区分响应未带该字段、明确 `null` 与有值。
- 将 Graph 的原始 `dueDateTime`（含时区）和原始 `status` 保存为同步影子数据；它们不进入 `QuadrantTask` 产品模型。
- 将远端更新改为字段级 PATCH：标题仅 `title`、完成仅 `status`、象限仅 open extension。没有本地日期变更时，绝不发送 `dueDateTime`；永不主动发送 `recurrence`。
- 本地“取消完成”明确映射为 Graph `notStarted`。Graph 的 `inProgress`、`waitingOnOthers`、`deferred` 在未发生本地完成切换时保持原状。

## 字段所有权

| 字段组 | 默认所有者 | Four Quadrants 策略 |
| --- | --- | --- |
| `recurrence` | Microsoft To Do | 原样缓存；没有创建或编辑 UI；PATCH 不发送 |
| `reminderDateTime`、`isReminderOn` | Microsoft To Do | 当前未映射；未来本地“进入紧急日”提醒必须是独立设置 |
| `dueDateTime` 与 `timeZone` | Microsoft To Do | 原始快照保留；只在用户改 Four Quadrants 日期时写日期语义 |
| `status`、标题、备注、重要性 | 共享 | 依据本地影子快照决定 PATCH 字段，使用 ETag |
| 象限、紧急阈值、置顶 | Four Quadrants | Graph open extension |
| ID、ETag、deltaLink、Outbox、影子快照 | 同步器 | 不进入业务 UI |

## 官方资料

- [todoTask 资源](https://learn.microsoft.com/en-us/graph/api/resources/todotask?view=graph-rest-1.0)
- [更新 todoTask](https://learn.microsoft.com/en-us/graph/api/todotask-update?view=graph-rest-1.0)
- [recurrencePattern](https://learn.microsoft.com/en-us/graph/api/resources/recurrencepattern?view=graph-rest-1.0)
- [recurrenceRange](https://learn.microsoft.com/en-us/graph/api/resources/recurrencerange?view=graph-rest-1.0)
- [todoTask delta](https://learn.microsoft.com/en-us/graph/api/todotask-delta?view=graph-rest-1.0)
- [Microsoft To Do 的日期、提醒与重复](https://support.microsoft.com/en-us/todo/add-due-dates-and-reminders-in-microsoft-to-do)

## 边际情况与待验证假设

- delta 查询可能省略字段；省略 `recurrence` 只更新观察状态为 `unobserved`，不得当作“无重复”。显式 `null` 才表示该响应明确无重复。
- 对 `title`、`body`、`importance`、`status`、`dueDateTime`、`completedDateTime` 同样区分 `unobserved`、显式 `null` 与值。已有本地任务只应用响应明确携带的字段；缺失字段保持当前本地值。明确 `null` 才执行清空或 Graph 默认值语义。
- 影子快照只在对应字段被 Graph 明确观察到时更新；稀疏响应不能把当前本地值冒充成远端已确认值。
- 只要同一任务存在 update/create Outbox 记录，拉取阶段不覆盖本地任务；包含 queued、inFlight、uncertain、retryableFailure、conflict 与 permanentFailure。推送阶段先 GET 最新远端，再按本地影子快照发送字段级 PATCH。delete 仍由墓碑路径单独处理。
- 遇到 412 时，先拉取最新 ETag 再按本地影子快照重算字段级 PATCH；远端同时改了重复规则时，Four Quadrants 不覆盖它。
- 离线完成只排队 `status=completed`。后续 delta 是最终事实，不在本地预生成下一轮。
- Graph 没有承诺重复任务完成后会保留 ID、生成新 ID 或重置原 ID；新 occurrence 是否继承 open extension 也未被本项目证实。
- 删除重复任务在 To Do 侧是否删除单次、整个规则或另有语义，尚须真实账号验证；首版不提供“仅跳过本次”。
- 精确到期时间、提醒、Graph 后续新增字段应由原始快照与缺省 PATCH 保护；当前 Four Quadrants 的日期显示仍是 civil-day 语义。
- 旧 `deltaLink` 的投影字段可能不含新字段。同步器使用查询版本号使旧链接失效并触发一次全量拉取。

## 真实账号验收

必须用 Microsoft To Do 建立至少一条复杂重复任务，记录完成前后 Graph delta 的 ID、ETag、`recurrence`、`dueDateTime`、`status` 与 open extension。再分别从 Four Quadrants 改标题、改象限、完成、取消完成，确认每次 PATCH 没有改变远端的重复、提醒和精确时间。

## 同步诊断

设置中的“同步诊断”运行普通的 `synchronize()` 路径，不创建探针任务，不写入随机数据。报告只保存开始/完成时间、成功状态、delta 条目数、导入/更新/删除数、因 pending Outbox 保留本地的数量、各字段的 `unobserved`/`null`/`value` 计数、PATCH 字段计数和错误摘要。报告不含任务标题、备注、远端 ID、账户标识或 access token，可复制用于排障。

需要确认某一任务的远端最终字段时，应使用明确的单任务 GET 诊断操作；常规同步诊断不会为此增加循环读取请求。

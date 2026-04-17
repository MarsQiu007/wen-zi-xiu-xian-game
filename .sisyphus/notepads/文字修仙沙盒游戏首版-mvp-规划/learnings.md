## 任务 1 学习记录

- Godot 4.6 首版骨架建议直接用 `GameRoot + UIRoot + SimulationRunner`，能把入口、UI、模拟三者边界拆清楚。
- Autoload 只保留最小职责：时间、运行态、存档、事件日志；不要提前做大而全服务容器。
- GDScript 中自定义类型引用在首版骨架阶段容易受加载顺序影响，主入口脚本先用通用 `Node` 更稳。

## 任务 2 学习记录

- 首版 Resource 数据层最好让所有静态数据共享同一组基础字段：`id`、`display_name`、`summary`、`tags`、`human_visible`、`deity_visible`，这样人类模式与神明模式可以用同一底层数据解释。
- Godot headless 烟雾验证里，脚本间 `class_name` / 继承链依赖容易受加载顺序影响；用于验证时，优先用 `get()` / 字段名做鸭子类型读取更稳。
- `String(...)` 构造器和 `?:` 三元写法都不是 Godot 4 GDScript 的可靠写法，验证脚本里应统一用 `str()` 和 `a if cond else b`。

## 任务 3 学习记录

- 时间推进首版应统一收口到 `TimeService.advance_day()/advance_days()`，分钟累计只作为底层计量，不要把业务直接分散到小时级排程。
- 事件日志首版必须保存结构化字段：`title`、`actor_ids`、`direct_cause`、`result`、`trace`；同时输出 `ENTRY|key=value` 格式，便于后续 QA 脚本解析。
- headless `--script` 验证下，模拟节点常常还没正式进树；这时比起依赖 Autoload 全局名，更稳的是显式注入 `TimeService`/`EventLog`/`RunState` 服务节点。
- 关键节点暂停最好下沉到事件模板字段 `pause_behavior`，这样后续人类模式、神明模式、区域事件都能共用同一暂停入口，而不需要在 Runner 里硬编码事件类型。
- 固定种子验证不仅要看退出码，还要对比结构化日志输出；同种子两次运行的 `ENTRY` 顺序和 `SUMMARY` 一致，才能证明冒烟结果真的可复现。

## 任务 6 学习记录

- 统一 smoke runner 的核心价值不只是“少一个脚本”，而是让后续所有任务都能复用同一套参数协议与输出格式，降低 QA 脚本碎片化风险。
- 在 Godot headless `--script` 入口里，顶层 `preload` 可能提前触发无关场景脚本编译；对 debug/boot 类任务，改用运行时 `load` 或直接读取 `.tscn` 文本更稳。
- 只要 `SUMMARY` 行稳定包含 `mode / seed / requested_days / advanced_days / resolved_days`，后续验证波次就能直接做机器断言，不必再靠人工阅读整段日志。

## 任务 4 学习记录

- 任务 4 的关键不只是“把区域名补齐”，而是让特殊点位也进入 `world_data_catalog.tres` 与统一 smoke/校验链，这样后续任务 8/11/12 才能直接复用这些世界挂点。
- 对首版世界布局来说，`parent_region_id` 很适合表达“妖岭附属于宗门山域”“废村贴近小城”这类层级关系，既保留地理上下文，又不必提前做地图系统。
- 首版势力关系暂时不必上复杂结构体；只要 `territory_region_ids + relations_summary` 能稳定读出“谁镇守哪里、谁警惕谁、谁争夺什么”，就足以支撑后续事件生成与 QA 验证。

## 任务 7 学习记录

- 对首版 NPC 系统来说，先把 `intent` 与 `method` 分离，比直接追求复杂行为树更关键：这样才能验证“目标方向一致，但道德值改变手段”。
- 焦点分层不需要一上来做三层完整精度模型；只要先让 focused 每日细更、background 按 3 日批量更新，并在 trace 里写明 `focus_tier / detail_level`，就足以支撑自动化验收。
- 任务 7 的最小实现最好用独立 fixture catalog 封闭验证环境，否则主世界角色样本太少，容易把任务 7 的验收和任务 8/11 的内容混在一起。

## 任务 8 学习记录

- 人类模式首版开局差异不需要复杂 UI 选择器；只要 `opening_type` 能稳定映射到不同年龄、压力和默认分支，就足以先验证“少年 / 青年 / 成年”三条前期节奏是否真的不同。
- “求仙机会需要主动争取”最适合做成可累计的接触值门槛，而不是一次性判定；这样 smoke 可以稳定比较 passive 与 active 两条路径的 `contact_score` 和 `opportunity_unlocked`，验证结果也更可重复。
- 统一 smoke runner 的可靠性不只体现在断言通过，还体现在进程必须按预期退出；因此任务收口阶段应同时看 `SUMMARY|failed=false` 和真实退出码 `EXIT=0`，两者缺一不可。

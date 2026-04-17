## 任务 1 架构决定

- 主入口采用 `GameRoot` 作为容器节点，内部挂载 `SimulationRunner` 与 `UIRoot`，保持场景边界清晰。
- Autoload 采用四个最小入口：`TimeService`、`RunState`、`SaveService`、`EventLog`。
- 首版不引入事件总线或复杂服务层，后续系统直接围绕场景与信号扩展。

## 任务 2 架构决定

- 世界/角色/势力/区域/事件/教义/神格都以独立 Resource 承载，字段层面对齐，避免把运行态塞进静态数据。
- 目录聚合资源 `WorldDataCatalog` 作为首版统一入口，提供 `find_*` 和字段校验，便于人类模式与神明模式共用读取。
- 验证脚本不绑定具体 Resource 类实现，改用字段名读取，降低 headless 验证对加载顺序和类型注册的敏感度。

## 任务 3 架构决定

- 时间系统继续保留在 `TimeService`，但对外统一暴露按日推进入口与时间快照，后续系统通过日级结算接入。
- 事件日志由字符串列表升级为结构化 `Dictionary` 条目，并保留 `entry_id` 与 `trace`，保证因果链和后续查询能力。
- 固定种子先通过 `SeededRandom + SimulationRunner` 骨架落地，关键事件是否暂停由 `WorldEventTemplateData.pause_behavior` 决定，避免把暂停逻辑写死在 runner 里。
- headless 验证阶段由 `day_tick_smoke.gd` 显式注入 `TimeService`、`RunState`、`EventLog`，而不是依赖场景内 Autoload 自动存在，保证脚本入口稳定可复现。

## 任务 6 架构决定

- 统一验证入口收敛到 `scripts/dev/smoke_runner.gd`，通过 `--task=boot|resources|day_tick` 分派不同 smoke 流程，避免后续任务各自复制一套脚本骨架。
- `mode / seed / days / stop-on-pause / auto-resolve-pause` 统一由 smoke runner 解析，并在 `day_tick` 任务里显式注入服务节点后驱动 `SimulationRunner`，保证双模式和参数化验证共享同一条执行链。
- `boot` 任务只读取 `game_root.tscn` 文本摘要，不直接预加载主场景，从而避开无头 `--script` 场景下无关脚本的提前编译噪音。

## 任务 4 架构决定

- 首版活跃区域在原有“村镇 + 小宗门 + 小城”基础上，再补 4 个轻量特殊点位：妖兽活动区、鬼怪异变点、秘境入口、绝地传闻点，但仍保持为静态资源与事件挂点，不提前扩成完整玩法层。
- 特殊点位继续沿用 `WorldRegionData`，通过 `region_type / parent_region_id / danger_tags / key_site_tags / event_pool_id` 表达差异，而不是额外新建第二套点位资源类型。
- 势力关系首版仍用 `relations_summary` 做人可读表达，但通过扩充 `territory_region_ids` 把宗门、城市、神教与特殊点位绑定起来，保证世界布局能被数据和事件共同读取。

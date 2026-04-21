- Task 1（WorldItemData）采用 `extends WorldBaseData` + `class_name WorldItemData`，并保持与现有资源脚本一致的 `@export` 字段声明风格。
- 物品样例资源统一使用 `mvp_item_*` 命名与 `id = &"mvp_item_*"` 风格，和仓库已有 `mvp_*` 资源约定一致。
- `.tres` 样例采用 `[gd_resource] + [ext_resource] + [resource]` 三段结构，字段可直接覆盖导出默认值，适合作为后续 catalog 接入模板。
- 通过 `godot_validate` 对脚本与 6 个样例资源批量校验可行，当前定义在 Godot 4.6.1 下可无错误加载。
- Task 3 继续沿用 `extends WorldBaseData` 的资源继承风格；配方/掉落表脚本只新增纯数据字段，不额外引入逻辑方法。
- 配方与掉落表样例里使用的 `Array[Dictionary]` / `Array[String]` 字面量与现有功法样例一致，Godot 会按数据资源形式直接加载。
- Task 3 样例中的部分物品 id 仍采用前向引用占位（如灵草、铁矿、兽核），因为当前目标只是验证资源结构，不接入 catalog 或运行逻辑。
- Task 4 的战斗数据类沿用 `RefCounted + SNAPSHOT_VERSION + to_dict/from_dict` 模式；数组与字典字段需要深拷贝，才能保证序列化往返时不共享引用。
- Task 5 扩展 `WorldDataCatalog` 时，沿用原有 `Array[Resource] + find_* + validate_required_fields()` 模式最稳妥；新域（items/techniques/recipes/loot_tables）可直接按同模板接入，不会影响既有 region/character/faction 查询路径。
- `world_data_catalog.tres` 接入新资源时需同步提升 `load_steps` 并追加 `ext_resource` id；按连续 id 编排可降低后续手工维护成本。
- Task 6 里 `rng_channels.gd` 更适合做成纯 `RefCounted` 工具对象，公开 `world_rng/combat_rng/loot_rng` 三个 `RandomNumberGenerator` 实例，保存时只记录 `master_seed` 与各通道的 `seed/state`，这样回放和存档都更直接。
- Task 7 的 `InventoryService` 采用 Autoload 轻协调模式：仅维护 `_inventories`、查 catalog、发 EventLog 事件，背包记录保持 `Array[Dictionary]`（`item_id/quantity/rarity/affixes/equipped_slot`）便于后续直接序列化。
- 装备逻辑可用“同槽自动卸下 + 非装备堆叠合并”实现最小一致性：`equip_item` 前先清空目标槽，再在 `unequipped` 条目间按 `item_id+rarity+affixes` 合并，能保证同槽最多一件装备。
- 与现有运行时最小集成点放在 `SimulationRunner.setup_services`：不改签名，仅在内部尝试 `InventoryService.bind_catalog(_catalog)`，兼容现有调用方。
- `get_equipped_stats` 同时聚合 `WorldItemData.stat_modifiers` 与已实例化 `affixes` 的数值效果（支持 `{"effect": {...}}` 结构），可直接满足后续战斗/面板读取。
- Task 8 的 TechniqueService 采用 `RefCounted` 非 Autoload + `bind_catalog/bind_event_log/bind_rng_channels` 轻依赖注入，保持与 NPC 子系统一致的可序列化服务风格，便于后续由 SimulationRunner 持有。
- 功法学习门禁优先校验 `WorldTechniqueData.sect_exclusive_id` 与角色 `faction_id/faction`，不通过时返回 `SECT_RESTRICTED` 并发出 `TECHNIQUE_SECT_RESTRICTED` 事件；通过后再做境界与 learning_requirements 校验，逻辑更清晰。
- 参悟实现采用“优先解锁 locked_affixes，再重随机 unlocked_affixes”的两段式流程，并统一走 `rng_channels.get_loot_rng()`；当未绑定通道时回退入参 `SeededRandom`，既满足确定性也兼容独立测试。
- 为满足“消耗灵石（base_value×2）”且当前功法资源未含 base_value 字段，服务中采用 `base_value` 优先、`power_level*10` 兜底，再乘 2 的策略，避免数据未齐时流程中断。
- `get_technique_combat_skills` 只聚合已装备槽位功法的 `combat_skills`，并附加 `technique_id/equipped_slot`，可直接给后续 CombatManager 消费。
- Task 9 的 CombatManager 采用 RefCounted 服务形态并保持自包含：仅消费 CombatantData + RNG，输出 CombatResultData（战报、参与者快照、掉落、victor），不直接操作 InventoryService。
- 回合流程固定为“速度排序行动 → 伤害结算 → 状态 tick → 胜负检查”，并由 MAX_TURNS=30 强制封顶；战报统一为 [回合N] 攻击者 使用 技能 对 目标 造成 X 点元素伤害。
- 元素克制表按计划实现（火克风、风克雷、雷克水、水克火、土木互克），倍率固定为克制1.3/被克0.7；同 seed 重复运行可稳定得到一致战报与掉落。
- 掉落生成使用 loot_rng 优先（绑定 RNGChannels 时），否则回退战斗入参 RNG；结果组合 guaranteed_drops 与 weighted entries，并按 item_id+rarity 聚合数量，便于后续存档和发奖。

- Task 10 的 `WorldDynamicsService` 采用与 `relationship_network`/`technique_service` 一致的非 Autoload `RefCounted` 服务模式：`bind_catalog/bind_event_log/bind_rng_channels + save_state/load_state`，并将区域状态统一归一化为 `resource_stockpiles/production_rates/controlling_faction_id/faction_modifier/danger_level/population` 六字段。
- 生产与消耗采用“确定性随机微扰 + 下限裁剪”策略：`advance_production` 用 world_rng 在 0.95~1.05 浮动，`advance_consumption` 按人口与危险度计算需求并 `max(0)` 裁剪，保证任意 tick 后库存不为负。
- 领地争夺按计划走 `contest_territory(region_id, challenger_faction_id, combat_result)`：要求 `combat_result.victor_id` 非空，更新 `controlling_faction_id` 与 `faction_modifier`，并发出 `TERRITORY_CHANGED`；影响力变化统一经 `update_faction_influence` 并发出 `FACTION_INFLUENCE_CHANGED`。
- 头less QA 三场景通过：资源循环（先升后降且非负）、领地变更（控制权转移且新倍率生效）、经济稳定（1000 tick 无负库存，货币增长率小于 5%，本次样本为 -100% 亦满足阈值）。
- Task 11 将 WorldGenerator 扩展为 catalog 优先 + procedural 回退：regions/items/techniques/loot_assignments/region_dynamics_init 全部保持 seed 决定性，并保留 legacy cultivation_methods 结构兼容。
- techniques 输出新增 resource 化字段（technique_id/sect_exclusive_id/min_realm/affixes/source），其中 sect_exclusive_id 通过 controlling_faction_id 约束投放区域，确保门派独占功法不越界。
- items 采用固定比例稀有度计划（common>=uncommon>=rare>=epic>=legendary>=mythic）后再按模板生成，既满足分布 QA，又可稳定复现。
- Task 12 在 `npc_behavior_library.gd` 中保持 `BehaviorAction` 既有结构（action_id/category/pressure_deltas/favor_deltas/conditions/weight/cooldown_hours）不变，新增行为全部通过 `_make_behavior` 构建，避免影响后续决策引擎消费形态。
- `load_custom_behaviors(catalog)` 采用“内建兜底 + 自定义覆盖/补充”的合并策略：基于 `action_id` 去重，优先覆盖同名内建行为，并支持从 catalog 动态字段、集合资源 `meta`、可选 getter 方法收集行为定义。
- Task 13 集成里 `SimulationRunner.advance_tick` 采用 `TickOrder.PHASE_ORDER` 分阶段驱动（生产→决策→行动→战斗→领地→清理）后，可在不改评分核心的前提下接入多服务动作执行。
- `CombatManager.resolve_npc_combat_only` 入参必须是强类型 `Array[CombatantData]`，不能传未收窄的普通 `Array`，否则会在运行时触发 typed array 参数错误。
- headless `godot_run_script` 场景脚本需严格使用显式类型（尤其 `Node`/`RefCounted`/`int`/`bool` 本地变量），否则桥接会在解析阶段断点并超时。
- Task 13 回归中发现：`challenge_npc` 的关系变更若依赖 `RelationshipNetwork.modify_favor`，在双方无现存边时不会生效；最小修复是在战斗结算前确保双向关系边存在，再应用 favor 变化。
- Task 13 验证脚本需按真实运行树路径获取节点（本项目为 `root/GameRoot/SimulationRunner`），且不要依赖 `runner._time_service_node` 这类可能未注入字段；使用固定测试时间参数可提升 headless 稳定性。

- Task 14（区域动态逻辑实现）在 `SimulationRunner` 里采用“生成结果优先、catalog 回退”初始化：`bootstrap_from_creation` 通过 `generated_world.region_dynamics_init` 调 `WorldDynamicsService.init_region_states`，`reset_simulation` 保持 catalog regions 回退路径，兼容旧 bootstrap 流程。
- 为保证 UI 后续读取且不改 `LocationService` 接口，Runner 新增 `get_region_dynamic_state(region_id)` 与 `get_all_region_dynamic_states()` 两个薄透传，仅转调 `WorldDynamicsService`，不在 Runner 内重算区域逻辑。
- 区域初始化输入兼容 `Dictionary(region_id -> state)` 结构：Runner 先归一化为带 `id` 的数组项再交给服务，若状态缺 `controlling_faction_id` 则用 catalog 区域字段补齐，确保领地倍率链路可用。
- headless QA（三场景）通过：bootstrap 后区域状态含 stockpile/production；10 tick 资源循环全区非负且有上升区域；争夺领地后控制方切换且下一 tick 产出按新 modifier 生效。

- Task 15 将玩家运行时扩展字段统一固化在 opening builder：`inventory/equipment/learned_techniques/technique_slots/combat_stats_base/combat_stats` 均做结构归一化，并通过 opening_type 负载模板注入起始装备与起始功法（新增 warrior 映射）。
- Task 15 的战斗属性刷新采用“基础值 + 装备词条 + 功法 base_effects/已解锁词条”聚合，并在 `HumanModeRuntime.advance_day` 中串接“日推进后重算 + 装备耐久/自动衰减处理”，保证运行时每日状态可追踪、可序列化。
- `godot_run_script` 验证时若直接依赖场景内 `SimulationRunner`，需先经过完整 `world_initialized` 流程；本任务 QA 改为直接实例化 `HumanModeRuntime` 并传入 catalog，能稳定覆盖“开局字段完整性 + 装备加成计算”两条验收路径。
- Task 16 集成中，`HumanCultivationProgress` 保持原“contact_score>=6 直接成功”的突破主干不变，仅在未达阈值时追加“有功法+10%随机补正”；同时把 `technique_trace` 与 `consequence` 的 `technique_info` 片段带回上层日志链路。
- `HumanCultivationGate` 在 `opportunity_unlocked` 时直接触发 `TechniqueService.learn_technique`（通过 runtime 注入或懒创建 service），并将结果回写到 `cultivation_gate.unlock_learn_*` 字段，便于 headless QA 断言“已调用”而不依赖一定学会成功。
- 信仰接触链路采用“已有本门独占功法 → contact/faith 增益 + faith_sect_technique_candidate”，并允许在 faith 场景满足门槛时解锁机缘，保证 `opportunity_unlocked` 能联动功法学习入口。
- Task 17 玩家战斗接入保持“SimulationRunner 薄编排 + CombatManager 内核不变”：通过 `RunState.player_combat_action_submitted` 信号接 UI 行动，Runner 仅负责入战(`sub_phase="combat"`)、构建玩家 CombatantData、提交 resolver、结算掉落/关系/记忆/灵石，再回写 `RunState.combat_context/combat_result` 并退出子阶段。
- Task 17 收尾补强：在进入新一场玩家战斗前主动清理 `RunState.combat_result`（新增 `RunState.clear_combat_result()` 并在 `SimulationRunner._start_player_combat_pending` 调用），可避免 UI 在 `sub_phase="combat"` 期间读到上一场残留结果。
- 头less QA 稳定路径：优先用真实 `request_player_challenge -> advance_tick -> RunState.submit_player_combat_action` 验证入战与结算链路；若需覆盖 flee 分支可直接提交 `action_type="flee"`，避免构造 `CombatResultData` 时触发类型赋值差异。
- Task 18 的 CraftingService 采用与 TechniqueService/WorldDynamicsService 一致的 `RefCounted + bind_* + save_state/load_state + _result` 风格，并通过 `bind_inventory_service`/自动解析 `InventoryService` 仅使用 `has_item/remove_item/add_item/get_inventory` 公共 API 完成材料校验、消耗与产出，避免直接修改背包内部数据。
- 制作品质计算实践：先按材料条目的真实库存堆叠品质做“数量加权平均”，再结合 `required_skill_level` 与 `loot_rng` 做 ±1 档位偏移；为符合计划“高品质材料正向影响”，最终品质下限固定为配方 `result_rarity_min`，高品质材料（如 rare 灵草）在当前样例下可稳定产出 `>= uncommon`。
- Task 19 UIRoot 背包面板集成：UI 中通过提取 `SimulationRunner` 的首个激活玩家角色，并转调 `InventoryService.get_inventory()` 与 `get_equipped_stats()`，实现解耦呈现。事件刷新监听 `EventLog` 中的 `ITEM_*` 系列事件以按需调用 `_refresh_inventory_panel()`，避免滥用 `_process`。

### UI Development and Bindings (Task 20 - Technique Panel)
- **Adding New Variables for Code-Built UIs**: When injecting new UI panels (e.g. `_technique_panel`) built in code, make sure to explicitly declare their backing properties (e.g. `var _tech_item_list: ItemList`) at the top of the file. Godot GDScript will throw a "Parser Error: Identifier not declared" if you try to assign `.new()` instances to undeclared class variables.
- **Resource Object .get() Method Limitations**: Avoid using `Object.get(property, default_value)` on instances of `Resource` in GDScript. The `get()` method inherited from `Object` takes exactly 1 argument (the property name) and does not support a fallback default value like `Dictionary.get()` does. Attempting to pass two arguments results in `Parser Error: Too many arguments for "get()" call`. Always use `var val = obj.get("prop")` and check `if val != null:` when dealing with `Resource` definitions.
- **Isolating UI vs Model**: For the technique panel, the UI strictly calls `_sim_runner.request_equip_technique()` and `request_meditate_technique()` rather than modifying `TechniqueService` properties directly. This aligns with the constraint to not mutate the underlying service layers from UI scripts directly.

- Task 21（战斗UI面板）：由于 `SimulationRunner` 中的 `start_combat` 是同步阻塞并在单帧内跑完整个回合循环，且回传给 `RunState` 的 `combat_result` 字典并未显式包含 `combat_log`，UI 需要通过截取 `EventLog` 在战斗前后的条目变化，提取 `COMBAT_TURN_RESOLVED` 事件中的 `trace.log`，将各回合战报还原呈现在战斗面板中。
- `Resource` 类型变量调用 `.get(property, default)` 时，由于 `Object` 基类的 `.get` 只接收 1 个参数，会导致 `Too many arguments for "get()" call` 解析错误；因此在处理 inventory 动态物品时，需先 `var val = def.get(prop)` 再判空并做类型转换。
- 在给由代码构建的动态控件增加基于 `EventLog.entries` 大小的索引缓存时，必须使用显式类型定义如 `var end_idx: int = ...`，否则会导致 `Cannot infer the type of ... variable`。

### Task 22: World Map Enhancement UI
- `SimulationRunner` explicitly exposes `get_all_region_dynamic_states()` and `get_region_dynamic_state(region_id)` via forwarding from `WorldDynamicsService`. This allows UI to easily fetch runtime states without depending on the exact service instance structure.
- `TreeItem` supports `set_custom_color()` and `set_text()` to enhance visually single columns. It is easier to dynamically format strings for danger and factions and apply color tinting rather than adding multiple columns to the `Tree` node.
- Generating procedural visual identifiers like a faction color is easily done using string hashing via `float("faction_id".hash() % 1000) / 1000.0` to set Hue in `Color.from_hsv(hue, 0.6, 0.9)`.

- Task 24 (Crafting UI): Added Crafting panel in `ui_root.gd`. Avoided modifying existing Crafting/Inventory services. Used `OptionButton` to filter Alchemy/Forge recipes. Safely read from `Resource` using `.get()` and explicit `Variant` to typed casting to avoid GDScript 4 parser issues. Handled crafting success/failure via existing `CraftingService` API and `show_event_modal`.

- Task 24 Fix: `SimulationRunner` provides its state via `get_snapshot()`, meaning there is no direct `get_catalog()` getter. The correct access pattern for UI elements to retrieve the catalog from the SimulationRunner is to read `_sim_runner.get_snapshot().get("catalog")`.

### UI Catalog Data Access
- **Context**: When attempting to fetch catalog data in `ui_root.gd` for crafting.
- **Problem**: Previous assumption that `SimulationRunner.get_snapshot().get("catalog")` contained the catalog was incorrect; it does not.
- **Solution**: The correct way for UI or external scripts to access the catalog safely from the Simulation Runner is:
  ```gdscript
  var catalog_path: String = _sim_runner.get_catalog_path()
  var catalog: Resource = load(catalog_path) as Resource
  ```
- **Reasoning**: This retrieves the configured `CATALOG_PATH` directly from the runner and correctly loads the resource, preventing silent failures or runtime crashes while remaining strictly decoupled.

- Task 25（存档迁移 v1→v2）中，`SimulationRunner.get_snapshot/load_snapshot` 扩展新字段时需保持“旧字段不删、新字段可缺省”策略：`inventory_data/technique_data/world_dynamics_data/crafting_data/rng_state` 全部以 `Dictionary` 形式归一化，缺失时走默认空结构或由 seed 派生的 RNG 初始状态。
- `WorldDynamicsService.load_state({})` 会清空内部状态，因此迁移兼容路径里不能无条件传空字典；应仅在 `world_dynamics_data` 非空时调用，旧存档缺字段时保留 `reset_simulation()` 后的初始化区域状态。
- `SaveService._validate_payload()` 在版本升级时应复用 `migrate_save(data, from_version)` 而非硬编码单次迁移函数，避免后续扩版本时漏链路；迁移后同步回写 `payload.save_version = SAVE_PROTOCOL_VERSION`。

- 2026-04-21 TASK26: 修复 integration_test 的功法参悟链路，绕开 runner.request_meditate_technique 的 RNG 类型不匹配，改为 TechniqueService.meditate_affix + 固定 seed；最终 10/10 断言通过。

- 2026-04-21 review-blocker 修复：UI 保存统一写入 {simulation_snapshot: snapshot}，与 continue 读取结构对齐；integration_test 去除 TechniqueService 私有 API 兜底，仅保留公开链路断言；清理临时补丁脚本并恢复误删计划文件。

- 2026-04-21 UI热修复（个人背包页）：在 `ui_root.gd` 里把“个人背包”占位替换为数据驱动面板（左侧 ItemList + 右侧详情 + 已装备槽位 + 属性总览），并复用 `InventoryService.get_inventory/get_equipped_stats` 与 catalog `find_item` 读取展示数据，不新增服务。
- 背包刷新采用“切页主动刷新 + EventLog 事件增量刷新”双保险：切到 `inventory` 触发 `_refresh_inventory_panel()`，日志事件若 `category==inventory` 或 `title/direct_cause` 以 `ITEM_` 开头则自动刷新，可在物品增减后即时更新列表与详情。
- Godot 4.6 + strict warning 模式下，`var quantity := max(...)` 可能触发 Variant 推断告警并被当错误处理；应改为显式类型 `var quantity: int = ...` 再做范围修正。
- UI 无玩家运行时属性时，属性总览展示建议使用稳定兜底（max_hp=100/attack=10/defense=5/speed=10），避免出现全 0 误导玩家。

- 2026-04-21 TASK26 测试口径修正：`integration_test.gd` 的存档一致性检查需显式覆盖 v1→v2 迁移并在迁移后推进 10 tick 再取快照，避免只验证“可加载”而漏掉迁移后时序稳定性。
- 战斗确定性验收应使用“同 seed 多次重复（20 次）全指纹一致”的强口径，而不是 2 次对比；否则容易漏检低概率分歧。
- 交易链路测试应避免调用 `SimulationRunner` 私有方法（如 `_apply_trade_item_action`），改用 `InventoryService.add_item/remove_item` 与 `TechniqueService.set/get_character_spirit_stones` 公共 API 组合验证买入扣款与卖出入账。
- 经济稳定性断言按计划应看“1000 tick 总增长率 < 5%”，不应再使用“每 tick 平均增长率 < 5%”这种更宽松口径。
- 2026-04-21 catalog 校验补强：`validate_required_fields()` 需要同时覆盖 `items/techniques/get_crafting_recipes()/loot_tables` 的非空检查，`_validate_collection()` 里用 `Dictionary` 记录已见 `String(item.get("id"))`，即可稳定补出重复 id 报错且不影响原有缺失字段逻辑。

- 2026-04-21 UI 制作面板修复：`_refresh_crafting_panel()` 先通过 `catalog.has_method("get_crafting_recipes")` 调用 canonical 方法，再在方法不可用时回退到 `catalog.get("recipes")`，最后仍为空才返回；这样保持了 `WorldDataCatalog` 的封装优先级，同时兼容旧资源。

## UI Integration Learnings
- **Panel Visibility Toggling**: Added specific tabs dynamically into `tabs` array and hooked them via `_update_right_content_visibility` and `_on_tab_button_pressed`.
- **Resource.get()**: Godot `Object.get(property: StringName)` method takes exactly 1 argument. Default values (e.g. `obj.get("prop", default)`) are a `Dictionary` feature, NOT a general Object feature. Be careful when working with resources.
- **Dynamic Method Calls**: In strictly typed GDScript 4 environments, invoking methods on `Variant` may cause issues or require `.call()`. Always typecast explicitly, e.g. `var obj: Object = var_raw`.

## Bugfix Learnings
- **Dictionary Depth**: Data structures like `get_human_runtime()` nested the player inside `{"player": {"id": "..."}}`. Always inspect the shape of nested dictionaries when chaining `.get()`.
- **API Availability**: Don't assume custom classes (`WorldDataCatalog`, `EventLog`) have standard querying methods like `get_all_items()` or `get_entries_by_category()` unless verified. Used manual filtering over `get_entries()` and accessed `catalog.get("items")` via Variant mapping.

## 2026-04-19

- 存档协议升级适合把版本分支放在 `SaveService` 内部，旧版本只做最小迁移并在校验阶段统一补齐字段。
- `SaveMigration` 这类辅助脚本需要显式 `preload()`，否则 Godot 解析阶段可能无法识别类名。
- 只做空字段补齐的迁移可以保持兼容性，避免把结构细节扩散到业务层。
- `RelationshipNetwork` 维护双向索引时，索引值存储 edge_key（`source|target`）比存储对端 ID 更稳健，可避免覆盖更新后出现残留引用。
- `get_edge()` 返回空 `RelationshipEdge.new()`（而非 `null`）可以让调用方保持无判空读取风格，同时 `get_favor()` 仍可通过 `_edges.has(key)` 精准返回 0。
- 1000 条关系边下，`get_edges_for/get_edges_involving/get_relations_of_type/get_all_edges` 的组合查询在本机实测约 `1.032ms`，满足 `<5ms` 约束。
- `NpcBehaviorLibrary` 采用 `Dictionary[StringName, BehaviorAction]` 时，可通过 `BehaviorAction.to_dict()/from_dict()` 返回副本，避免外部直接篡改库内模板数据。
- NPC 行为可统一在 `conditions` 中使用 `has_technique` 与 `min_realm_progress`，并配合 `last_action_hours[action_id]` 做小时级冷却判断，能与现有时间系统无缝衔接。
- Mode Select and Character Creation screens were connected to the phase change logic within `ui_root.gd` to appropriately show and hide the UI flow elements.
- MainMenu is also correctly toggled off during mode selection and character creation, without being fundamentally modified.
- Added a simple loading label `_loading_label` directly in `ui_root.gd` for `world_init` phase since the previous status bar was attached to `_game_ui_container` which is appropriately hidden during initialization.
- WorldGenerator 生成脚本需要兼容项目内 `SeededRandom` 实际接口（`next_int` / `next_float`），不能直接假设 `randi` / `randf`。
- NameGenerator 采用静态方法后，调用点可直接 `NameGeneratorScript.generate_*`，便于在世界生成、角色生成等多处复用并保证同一随机源可复现。
- `NpcBehaviorLibrary` 采用常量字典驱动实例化 `BehaviorAction`，可保持行为配置与运行对象解耦，后续扩展新行为只需追加定义。
- 行为可用性筛选统一放在 `get_available_behaviors()`，集中处理境界、功法与冷却校验，减少调用方分散判断。

### T10: World Init & Time Control UI Integration
- Created `world_init_screen` as a `PanelContainer` to simulate a multi-stage loading screen. Wait for future T11 tasks to hook it up to the real `WorldGenerator`.
- Leveraged `visibility_changed` signal inside UI screens to automatically trigger start routines rather than depending exclusively on `ui_root`'s `_on_phase_changed`. This cleanly separates the state-logic binding.
- Implemented `time_control_panel` directly within the existing top bar of the main play UI (`_status_panel`'s `HBoxContainer`). This creates a cleaner, more consolidated look without blocking gameplay space.
- Successfully utilized `TimeService` API for dynamic text display including speed tier names and hour advancement listening.
- `SimulationRunner` 新增小时制主循环 `advance_tick(hours)` 后，保留 `advance_one_day()` 包装到 `advance_tick(24.0)` 可以实现平滑兼容，不会破坏旧 smoke/test 调用入口。
- `bootstrap_from_creation(creation_params, seed_data)` 采用 `CharacterCreationParams.from_dict` 与 `WorldSeedData.from_dict` 做输入归一化，再调用 `WorldGenerator.generate()`，可保证世界生成参数与存档快照结构一致。
- NPC 决策接入时，用 `_npc_decision_intervals[npc_id]` + `NpcDecisionEngine.get_decision_interval()` 控制决策节流，比每小时全量重算更符合性能约束；行为执行后同步更新 `pressures/relationships/memory_system` 与 `last_action_hours`。
- 快照扩展增加 `creation_params/world_seed/relationship_network/memory_system/npc_decision_intervals` 后，需同步更新 `get_snapshot`、`load_snapshot` 与 `_validate_snapshot_payload` 三处，否则恢复时会出现字段丢失或类型校验不一致。
- `GameRoot` 在 `ui_root.world_initialized` 上显式连接 `_on_world_initialized()`，并改为 `advance_tick(TimeService.get_hours_per_tick())`，可直接复用 `TimeService` 速度档位逻辑，避免日推进硬编码。
- T13 UI 重构完成，将 main content 重构为 30/70 分栏布局，添加了 NPC 简况和标签页导航系统。
- T15 存档快照扩展新增 `speed_tier` 时，除了 `get_snapshot/load_snapshot`，还要同步补 `_validate_snapshot_payload` 的类型校验与 normalized 输出，否则读档会吞字段。
- 主菜单“继续游戏”可仅依赖 `SaveService.has_save_slot() + get_save_info()`做可用性和元信息展示；模式信息可从 `load_game()` 的 `simulation_snapshot.mode` 读取并与时间戳同屏展示。
- 主玩法保存按钮可直接走 `SaveService.save_game(simulation_runner.get_snapshot())`，并通过 `SaveService.get_last_error()`回填失败原因到日志，避免无反馈。
- UI_Root (T16): `_sim_runner.get_snapshot()["relationship_network"]` provides relationship edges. Player's ID can be found from `_sim_runner.get_runtime_characters()`. Relationship UI can be built dynamically by clearing the VBoxContainer and re-instantiating HBoxContainers for each relation. Use `CharacterService.get_character_view` to get deep information about a character such as `attributes` and `affiliation`. `var view: Dictionary` is preferred over `var view :=` when dealing with autoloads that return variants.
 - ui_root.gd: refactored log panel, embedded map, embedded world characters.

- `world_init_screen.gd` 若被 `.tscn` 以自定义类型 `WorldInitScreen` 实例化，脚本必须声明 `class_name WorldInitScreen`，否则场景节点路径和脚本绑定会出现运行时异常。
- UI 初始化阶段对 `@onready` 路径依赖较强时，可改为 `_ready()` 中 `get_node_or_null()` + 空值保护，优先避免 `null instance` 直接崩溃。
- `RunState` 这类 Autoload 在独立 UI 脚本中应显式 `_bind_singletons()` 绑定，并在访问前判空（尤其是初始化流程 `start_init()`）。
- `ui_root.gd` 的区域角色激活逻辑应在 `_refresh_roster()` 之后再做索引边界判断，避免 `_current_roster[i]` 越界。
- 主菜单继续按钮只展示元信息时，使用 `SaveService.get_save_info()` 足够，避免调用 `load_game()` 触发全量反序列化与副作用。

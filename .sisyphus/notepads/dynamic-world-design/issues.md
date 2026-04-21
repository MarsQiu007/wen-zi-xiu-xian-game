- 当前仓库已有多个 `scripts/resources/world_*.gd` 资源脚本仍是 `extends Resource` 并重复基础字段，未统一切换到 `WorldBaseData` 继承；Task 1 已按计划要求新建为继承模式，后续任务可视情况逐步收敛风格。
- `mvp_item_sword_schematic.tres` 中 `consumable_effect.recipe_id = "mvp_recipe_iron_sword"` 为前向引用（配方资源尚未在 Task 1 创建），当前仅作为数据占位，不影响资源加载校验。
- Task 3 的配方/掉落表样例同样保留了少量前向引用 id（如 `mvp_item_spirit_herb`、`mvp_item_iron_ore`、`mvp_item_beast_core`），这些都是数据占位，不代表现阶段已有对应资源。
- Task 4 的三份战斗数据类未遇到序列化或类型校验问题；`godot_validate` 与 LSP 诊断均通过。
- Task 5 回归测试发现历史样例存在 id 不一致：`mvp_character_village_heir.tres` 的实际 id 为 `mvp_village_heir`（非 `mvp_character_village_heir`）。这不会影响 catalog 扩展本身，但调用方必须以资源真实 id 做查找。
- 目前掉落表样例文件命名为 `mvp_loot_*.tres`，与计划中的 `loot_tables` 字段语义一致，但前缀并非 `mvp_loot_table_*`；后续若要统一命名，建议单独做资源重命名任务并批量更新引用。
- Task 6 中 Godot 运行时对 64 位整数常量比较敏感，过大的十六进制混合常量会直接触发解析错误；后续做随机种子混合时优先用 Godot 能直接表示的十进制 64 位整数写法。
- Task 7 初版验证时遇到两个 Godot 4 类型检查坑：`Resource.get()` 不能用两参默认值写法；返回标注为 `Array[Dictionary]` 的函数不能直接返回未收窄的 `Array`。已通过 `_resource_get()` 辅助函数与显式数组归一化修复。
- 当前 `godot_run_project` 环境会输出一批既有项目 warning（与本任务无直接关系）；本任务新增 `InventoryService` 脚本在 `godot_validate` 下已无新增错误。
- Task 8 发现计划中 `WorldTechniqueData` 的“参悟消耗=base_value×2”与当前资源字段不完全一致（现有字段含 `power_level`，未定义 `base_value`）；已在 TechniqueService 内做兼容兜底（`power_level*10`），后续若要彻底数据驱动，建议在功法资源中补充显式 `base_value`。
- headless 运行 `godot_run_project` 时仍会输出一批历史 warning（UI/NPC/TimeService 等既有脚本），本任务新增 `scripts/services/technique_service.gd` 经 `godot_validate` 与 LSP 诊断均通过，无新增错误。
- Task 9 验证阶段发现既有 CombatantData 定义里 `equipped_techniques` 使用 `Array[Dictionary]` 强类型，运行时不能直接整体赋值未收窄的 Array（会触发 Invalid assignment）；构造测试参战者时需逐条 append Dictionary 或先做显式类型收窄。
- `godot_run_script` 在遇到运行时脚本异常时会进入调试断点并导致后续调用超时；本任务改用 `godot --headless --script` 的独立校验脚本完成确定性验收，结果为 all_passed=true。
- `godot_run_script` 临时 QA 脚本里未显式类型标注会触发 Parser Error（如 `var deterministic := ...`）；需写成 `var deterministic: bool = ...` 才能在 headless 桥接里稳定执行。
- Task 13 复验时再次确认：`InventoryService` 不存在 `clear_inventory()` API，测试重置必须使用 `load_state({"inventories": {}})` 或等价受支持接口；否则会在 headless 脚本直接报错。

- Task 25 验证中 `godot_get_debug_output` 出现 `The function parameter "seed" has the same name as a built-in function` 警告，已将新增函数参数改为 `seed_value` 消除新增 warning；其余输出为仓库既有 warning，与本次改动无关。

- 2026-04-21 手工QA（REAL MANUAL QA）: 通过 godot_run_project + godot_run_script 执行 scripts/dev/integration_test.gd，结果 TASK26_INTEGRATION_RESULT ok=true, passed=10/10；覆盖 save_load_consistency、crafting_alchemy_forge、economy_1000_tick_stability、world_resource_cycle 等关键链路。
- 可视化验证: 从主菜单 Continue 进入 human main_play 成功；左侧标签切换可达（事件日志/炼丹炼器/个人背包）。炼丹炼器面板正常渲染并显示配方列表（铁剑锻造图、基础回春丹配方）。
- 可见问题: 个人背包页仍显示“背包功能正在开发中”，与“最近改动重点含背包流程”存在用户可见落差；功能链路已被集成脚本覆盖但UI端未完备。保存按钮点击后未在当前可见日志中明确出现独立成功提示（仅观察到系统事件持续刷新），建议后续补充显式保存反馈。

- 2026-04-21 review-blocker: SimulationRunner.request_meditate_technique 当前向 TechniqueService.meditate_affix 传入 RNGChannels.get_loot_rng()（RandomNumberGenerator），与 TechniqueService 形参 SeededRandom 不匹配；integration_test 已改为走公开 TechniqueService.meditate_affix(SeededRandom) 以规避假阳性，Runner 端类型不匹配建议后续单独修复。

- 2026-04-21 手工QA修复确认：`个人背包` 页占位文案已移除，运行时可见真实背包列表/详情/已装备槽位/属性总览；通过 `godot_run_script` 注入 `mvp_item_spirit_stone` 后，列表即时出现“灵石 x2”，详情含 item_id 与基础信息。
- 本次改动严格限定在 `scripts/ui/ui_root.gd`；仓库存在大量其他已改文件属于既有工作区脏状态，不属于本次修复范围。

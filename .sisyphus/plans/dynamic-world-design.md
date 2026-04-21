# 动态世界物品与玩法系统设计

## TL;DR
> **Summary**: 为文字修仙游戏设计并实现5大互联系统——世界物品(装备/材料/消耗品/炼丹炼器/交易)、功法(词条+品质+门派独占)、文字回合制战斗、世界动态(NPC自主+资源产出+领地变迁)，按6波纵向切片交付。
> **Deliverables**: Item/Technique/Recipe/LootTable Resource体系、InventoryService/TechniqueService/CombatManager/WorldDynamicsService、NPC行为扩展与数据驱动迁移、玩家背包/功法/战斗/制作流程、6套UI面板、存档迁移v1→v2
> **Effort**: XL
> **Parallel**: YES - 6 Waves
> **Critical Path**: Wave1(数据模型) → Wave2(核心服务) → Wave3(世界生成+NPC) → Wave4(玩家系统) → Wave5(UI) → Wave6(存档集成)

## Context
### Original Request
分析当前仓库人类玩法，设计世界物品、世界地图、功法等等，参考鬼谷八荒和太吾绘卷的动态世界物品，提升游戏可玩性。

### Interview Summary
- **分期策略**: 一次性全规划，分波实现
- **功法深度**: 词条+品质+门派独占（参考鬼谷八荒）
- **物品范围**: 完整体系（装备+材料+消耗品+炼丹炼器+交易）
- **战斗系统**: 纳入，文字回合制
- **世界动态**: NPC自主+资源产出+领地变迁（最深档）
- **世代传承/轮回**: 不纳入，后续扩展
- **测试策略**: tests-after（项目无测试基础设施，需搭建）
- **NPC规则一致性**: NPC使用近似模拟（简化计算），与玩家共享核心规则但允许NPC走快捷路径
- **世界推进粒度**: 每日推进，战斗在单tick内解决
- **失败可逆性**: 战斗失败=可逆，领地丢失=不可逆
- **存档策略**: 跨版本需迁移+警告

### Metis Review (gaps addressed)
- **跨系统数据耦合**: 定义统一事件总线契约，禁止UI/行为层直接改底层状态
- **RNG确定性**: 分RNG通道（world_rng/combat_rng/loot_rng），固定tick执行顺序
- **经济闭环**: 加入损耗/税费/耐久衰减作为sink，需1000tick仿真回归验证
- **存档迁移雪崩**: 每波升级schema_version并附迁移测试
- **行为库硬编码**: 规划从BEHAVIOR_DEFS到数据驱动资源的迁移路径
- **Autoload纪律**: Autoload仅做协调入口与生命周期管理，业务逻辑放scripts/services/

## Work Objectives
### Core Objective
实现一个"活"的修仙世界——物品有品质词条差异、功法有门派独占与参悟深度、战斗有策略选择、世界有NPC自主行为与领地变迁，让每次游戏体验不同。

### Deliverables
1. **物品数据体系**: WorldItemData Resource + .tres模板 + 品质/词条/装备槽位定义
2. **功法数据体系**: WorldTechniqueData Resource + .tres模板 + 词条槽/门派独占/参悟机制
3. **制作与掉落**: CraftingRecipe + LootTable Resource + 炼丹/炼器/掉落逻辑
4. **战斗数据类型**: CombatantData/CombatAction/CombatResult + 回合制引擎
5. **InventoryService**: 背包增删改查/装备穿戴/消耗品使用
6. **TechniqueService**: 功法学习/参悟词条/装备到技能槽
7. **CombatManager**: 文字回合制战斗引擎（先攻判定→行动选择→伤害结算→胜负判定）
8. **WorldDynamicsService**: 区域资源产出/消耗、宗门势力扩张/衰落、领地变更
9. **WorldGenerator扩展**: 生成物品/功法/掉落表/动态区域状态
10. **NPC行为扩展**: 物品采集/交易/功法学习/战斗挑战/领地争夺行为
11. **NPC决策集成**: 新行为接入评分系统、冲突行为→CombatManager
12. **玩家系统集成**: 背包/装备/功法/战斗/制作完整流程
13. **6套UI面板**: 背包/功法/战斗/世界地图增强/交易/制作
14. **存档迁移v1→v2**: snapshot扩展+迁移函数

### Definition of Done (verifiable conditions with commands)
- [ ] `godot_validate` 全部脚本和场景无错误
- [ ] 固定seed世界生成产出一致的物品/功法/区域状态
- [ ] 角色可拾取物品→装备→查看属性变化
- [ ] 角色可学习门派功法→参悟词条→装备到技能槽
- [ ] 文字回合制战斗可复现（同seed 20次结果一致）
- [ ] NPC自主采集资源/学习功法/发起战斗/争夺领地
- [ ] 区域资源每tick产出/消耗，宗门领地可变更
- [ ] 炼丹/炼器可制作物品，品质受材料影响
- [ ] 交易可买卖，价格受阵营关系影响
- [ ] 存档v1可迁移到v2并正常加载
- [ ] 1000tick仿真无经济崩盘（总货币增长<5%）

### Must Have
- 物品6级品质（凡品→灵品→仙品+3中间档）
- 功法词条槽+参悟机制+门派独占门禁
- 文字回合制战斗（选择功法/使用物品/逃跑）
- NPC每日自主决策（含物品/功法/战斗/领地行为）
- 区域资源产出/消耗循环
- 宗门领地变更（势力扩张/衰落）
- 炼丹+炼器基础制作
- NPC交易（买卖+阵营关系价格修正）
- 存档迁移v1→v2

### Must NOT Have (guardrails)
- ❌ 不做世代传承/轮回/传剑（明确排除，后续扩展）
- ❌ 不做多人联机
- ❌ 不做图形化地图（维持文字界面）
- ❌ 不重构现有Autoload架构（仅扩展，不改接口签名）
- ❌ 不在Autoload中堆业务逻辑（业务逻辑放scripts/services/）
- ❌ 不允许UI/行为层直接修改SimulationRunner底层状态（通过服务接口）
- ❌ 不允许跨系统RNG混用（world/combat/loot分通道）
- ❌ 不允许一次性跨多版本无测试迁移

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: tests-after + 搭建Godot headless测试基础设施
- QA policy: 每个任务有agent-executed happy+failure场景
- Evidence: .sisyphus/evidence/task-{N}-{slug}.{ext}
- 验证工具: `godot_validate`(脚本合法性) + `godot_run_script`(headless仿真断言) + `godot_get_debug_output`(日志收集)

## Execution Strategy
### Parallel Execution Waves
> Wave1: 6 tasks (data foundation, all parallel)
> Wave2: 4 tasks (core services, some parallel)
> Wave3: 4 tasks (world gen + NPC, sequential)
> Wave4: 4 tasks (player systems, some parallel)
> Wave5: 6 tasks (UI, mostly parallel)
> Wave6: 2 tasks (save + integration, sequential)

Wave 1: 数据基础层 — 6 tasks — all parallel
Wave 2: 核心服务层 — 4 tasks — #7∥#8, then #9∥#10
Wave 3: 世界生成与NPC集成 — 4 tasks — #11→#12→#13, #14∥#13
Wave 4: 玩家系统集成 — 4 tasks — #15→(#16∥#17∥#18)
Wave 5: UI实现 — 6 tasks — all parallel
Wave 6: 存档与集成验证 — 2 tasks — #25→#26

### Dependency Matrix (full, all tasks)
| Task | Depends On | Blocks |
|------|-----------|--------|
| 1. ItemData Resource | - | 5,7,11,15,19 |
| 2. TechniqueData Resource | - | 5,8,11,16,20 |
| 3. Recipe & LootTable Resources | - | 5,9,11,18,24 |
| 4. Combat Data Types | - | 5,9,12,17,21 |
| 5. WorldDataCatalog Extension | 1,2,3,4 | 10,11,14 |
| 6. Event Bus Contracts | - | 7,8,9,10 |
| 7. InventoryService | 1,6 | 11,12,15,19 |
| 8. TechniqueService | 2,6 | 11,12,16,20 |
| 9. CombatManager | 2,4,6 | 12,13,17,21 |
| 10. WorldDynamicsService | 5,6 | 14 |
| 11. WorldGenerator Extension | 1,2,3,5,7,8 | 14,15 |
| 12. NPC Behavior Library Extension | 7,8,9 | 13 |
| 13. NPC Decision Engine Integration | 12 | - |
| 14. Region Dynamics Logic | 10,11 | - |
| 15. Player Runtime Extension | 7,11 | 16,17,18,19 |
| 16. Cultivation+Technique Integration | 8,15 | 20 |
| 17. Player Combat Participation | 9,15 | 21 |
| 18. Alchemy & Crafting System | 3,7,15 | 24 |
| 19. Inventory Panel UI | 7,15 | - |
| 20. Technique Panel UI | 8,16 | - |
| 21. Combat UI | 9,17 | - |
| 22. World Map Enhancement | 10,14 | - |
| 23. Trade/Shop UI | 7,15 | - |
| 24. Crafting UI | 18 | - |
| 25. Save Migration v1→v2 | ALL above | 26 |
| 26. Integration Verification | 25 | - |

### Agent Dispatch Summary
| Wave | Tasks | Categories |
|------|-------|-----------|
| 1 | 6 | deep(3) + quick(3) |
| 2 | 4 | deep(2) + unspecified-high(2) |
| 3 | 4 | deep(2) + unspecified-high(2) |
| 4 | 4 | deep(2) + unspecified-high(2) |
| 5 | 6 | visual-engineering(6) |
| 6 | 2 | unspecified-high(2) |

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. 物品数据资源 WorldItemData + 样例 .tres

  **What to do**:
  1. 创建 `scripts/resources/world_item_data.gd`，继承 `WorldBaseData`（`scripts/resources/world_base_data.gd`），新增导出字段：
     - `item_type: String`（"weapon"/"armor"/"accessory"/"consumable"/"material"/"schematic"）
     - `rarity: String`（"common"/"uncommon"/"rare"/"epic"/"legendary"/"mythic"）
     - `stack_size: int`（默认1，材料类99）
     - `base_value: int`（基础灵石价值）
     - `equip_slot: String`（"weapon"/"head"/"body"/"accessory_1"/"accessory_2"/""）
     - `stat_modifiers: Dictionary`（如 {"attack": 10, "defense": 5}）
     - `affix_slots: int`（可携带词条数，0=无词条如材料）
     - `element: String`（"fire"/"water"/"thunder"/"wind"/"earth"/"wood"/"neutral"）
     - `required_realm: int`（使用/装备所需最低境界）
     - `consumable_effect: Dictionary`（消耗品效果，如 {"heal_hp": 50}）
  2. 创建样例 .tres 文件于 `resources/world/samples/`：
     - `mvp_item_iron_sword.tres`（凡品武器，攻击+8，无词条）
     - `mvp_item_fire_spirit_robe.tres`（灵品防具，火属性，防御+15，2词条槽）
     - `mvp_item_basic_healing_pill.tres`（凡品消耗品，回复HP 30）
     - `mvp_item_spirit_stone.tres`（凡品材料，stack_size=99，base_value=1）
     - `mvp_item_fire_essence.tres`（灵品材料，火元素，炼器用）
     - `mvp_item_sword_schematic.tres`（凡品图纸，制作配方引用）
  3. 每个字段添加中文注释说明用途
  **Must NOT do**:
  - 不修改 WorldBaseData 的现有字段
  - 不创建 InventoryService（那是 Task 7）
  - 不修改 WorldDataCatalog（那是 Task 5）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 需要理解现有 WorldBaseData 继承模式和 .tres 编辑方式
  - Skills: [`godot4-feature-dev`] - Godot 4 Resource 定义与 .tres 模板创建
  - Omitted: [`godot4-debugging`] - 无需调试

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [5,7,11,15,19] | Blocked By: []

  **References**:
  - Pattern: `scripts/resources/world_base_data.gd` - 继承基类，所有导出字段的定义方式
  - Pattern: `scripts/resources/world_character_data.gd` - Resource 子类示例，含导出字段和类型标注
  - Pattern: `resources/world/samples/mvp_character_village_heir.tres` - .tres 文件格式参考
  - API/Type: `scripts/resources/world_data_catalog.gd:WorldDataCatalog` - 最终需在此注册 items 数组

  **Acceptance Criteria** (agent-executable only):
  - [ ] `godot_validate(scriptPath="scripts/resources/world_item_data.gd")` 返回 valid=true
  - [ ] 6个 .tres 样例文件存在于 `resources/world/samples/` 且加载无报错
  - [ ] WorldItemData 所有导出字段有默认值且类型正确

  **QA Scenarios**:
  ```
  Scenario: 资源加载验证
    Tool: godot_run_script
    Steps: 运行脚本加载6个 .tres 文件，检查每个的 item_type/rarity/base_value 字段非空
    Expected: 全部加载成功，0 错误日志
    Evidence: .sisyphus/evidence/task-1-item-load.log

  Scenario: 非法字段防御
    Tool: godot_validate
    Steps: 创建一个临时 WorldItemData 实例，设 rarity="invalid_type"
    Expected: 脚本加载不崩溃（rarity为String类型不强制枚举，但运行时验证函数应返回false）
    Evidence: .sisyphus/evidence/task-1-item-invalid.log
  ```

  **Commit**: YES | Message: `feat(data): 添加物品数据资源WorldItemData与样例模板` | Files: [scripts/resources/world_item_data.gd, resources/world/samples/mvp_item_*.tres]

- [x] 2. 功法数据资源 WorldTechniqueData + 样例 .tres

  **What to do**:
  1. 创建 `scripts/resources/world_technique_data.gd`，继承 `WorldBaseData`，新增导出字段：
     - `technique_type: String`（"martial_skill"/"spirit_skill"/"ultimate"/"movement_method"/"passive_method"）
     - `element: String`（"fire"/"water"/"thunder"/"wind"/"earth"/"wood"/"neutral"）
     - `rarity: String`（同物品6级）
     - `min_realm: int`（学习最低境界）
     - `power_level: int`（威力等级1-10）
     - `affix_slots: int`（词条槽数，通常2-4）
     - `sect_exclusive_id: String`（空=野外功法，非空=门派独占，对应 faction_id）
     - `learning_requirements: Dictionary`（如 {"sword_qualification": 30, "fire_root": 20}）
     - `base_effects: Dictionary`（基础效果，如 {"damage_multiplier": 1.5, "mp_cost": 30}）
     - `combat_skills: Array[Dictionary]`（战斗中可用的技能列表，每个含 name/description/damage_type/base_damage/cooldown）
  2. 创建词条定义辅助类 `scripts/data/technique_affix.gd`：
     - `affix_id: String`、`affix_name: String`、`affix_category: String`（"offensive"/"defensive"/"utility"）、`effect: Dictionary`、`rarity: String`、`compatible_types: Array[String]`
  3. 创建样例 .tres 于 `resources/world/samples/`：
     - `mvp_technique_basic_sword.tres`（凡品武技，剑，无门派限制，1词条槽）
     - `mvp_technique_fireball.tres`（灵品灵技，火，无门派限制，2词条槽）
     - `mvp_technique_cloud_step.tres`（灵品身法，风，2词条槽）
     - `mvp_technique_sect_exclusive_azure_sword.tres`（仙品武技，剑，sect_exclusive_id="faction_azure_sect"，3词条槽）
     - `mvp_technique_iron_body.tres`（凡品被动心法，土，1词条槽）
  4. 创建词条样例 `resources/world/samples/mvp_affix_*.tres`（5-8个词条样例，攻防辅各2-3个）

  **Must NOT do**:
  - 不创建 TechniqueService（那是 Task 8）
  - 不修改 WorldDataCatalog（那是 Task 5）
  - 不实现参悟逻辑（那是 TechniqueService）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 功法系统复杂度高，需理解词条+门派独占的交互设计
  - Skills: [`godot4-feature-dev`] - Resource 定义与 .tres 模板
  - Omitted: [`godot4-debugging`] - 无需调试

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [5,8,11,16,20] | Blocked By: []

  **References**:
  - Pattern: `scripts/resources/world_base_data.gd` - 继承基类
  - Pattern: `scripts/resources/world_faction_data.gd` - faction_id 字段格式，sect_exclusive_id 需对应此格式
  - Pattern: `scripts/resources/world_event_template_data.gd` - 复杂 Dictionary 字段的 .tres 写法
  - Existing: `scripts/world/world_generator.gd:generate_cultivation_methods` - 现有功法生成逻辑（字典→需升级为Resource）

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/resources/world_technique_data.gd")` valid=true
  - [ ] `godot_validate(scriptPath="scripts/data/technique_affix.gd")` valid=true
  - [ ] 5个功法样例 + 5-8个词条样例加载无报错

  **QA Scenarios**:
  ```
  Scenario: 功法资源完整性
    Tool: godot_run_script
    Steps: 加载5个 technique .tres，验证每个 technique_type/min_realm/power_level/affix_slots 非空且类型正确
    Expected: 全部加载成功，0 错误
    Evidence: .sisyphus/evidence/task-2-technique-load.log

  Scenario: 门派独占验证
    Tool: godot_run_script
    Steps: 加载 mvp_technique_sect_exclusive_azure_sword.tres，检查 sect_exclusive_id 非空且为 "faction_azure_sect"
    Expected: sect_exclusive_id == "faction_azure_sect"，其余样例 sect_exclusive_id 为空
    Evidence: .sisyphus/evidence/task-2-sect-exclusive.log
  ```

  **Commit**: YES | Message: `feat(data): 添加功法数据资源WorldTechniqueData与词条定义` | Files: [scripts/resources/world_technique_data.gd, scripts/data/technique_affix.gd, resources/world/samples/mvp_technique_*.tres, resources/world/samples/mvp_affix_*.tres]

- [x] 3. 制作配方与掉落表资源 + 样例 .tres

  **What to do**:
  1. 创建 `scripts/resources/world_crafting_recipe_data.gd`，继承 `WorldBaseData`：
     - `recipe_type: String`（"alchemy"/"forge"）
     - `result_item_id: String`（产出物品 id）
     - `result_quantity: int`（默认1）
     - `result_rarity_min: String`（最低产出品质，受材料品质影响可升级）
     - `materials: Array[Dictionary]`（如 [{"item_id": "item_fire_essence", "quantity": 3}]）
     - `required_skill_level: int`（炼丹/炼器技艺等级需求）
     - `success_rate_base: float`（基础成功率0.0-1.0）
  2. 创建 `scripts/resources/world_loot_table_data.gd`，继承 `WorldBaseData`：
     - `entries: Array[Dictionary]`（每个含 item_id/weight/min_rarity/max_rarity/quantity_range）
     - `region_tags: Array[String]`（适用区域标签）
     - `monster_tags: Array[String]`（适用怪物标签）
     - `guaranteed_drops: Array[Dictionary]`（必掉物品）
  3. 创建样例 .tres：
     - `mvp_recipe_healing_pill.tres`（炼丹：3灵草→1回血丹）
     - `mvp_recipe_iron_sword.tres`（炼器：3铁矿+1火种→1铁剑）
     - `mvp_loot_village.tres`（村落掉落：灵石/灵草，低权重）
     - `mvp_loot_beast_ridge.tres`（兽岭掉落：兽核/灵材，中权重）

  **Must NOT do**:
  - 不实现制作逻辑（那是 Task 18）
  - 不实现掉落逻辑（接入 WorldGenerator 和 CombatManager）

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 结构清晰的 Resource 定义，跟随现有模式
  - Skills: [`godot4-feature-dev`] - Resource 定义
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [5,9,11,18,24] | Blocked By: []

  **References**:
  - Pattern: `scripts/resources/world_base_data.gd` - 继承基类
  - Pattern: `scripts/resources/world_event_template_data.gd` - Array[Dictionary] 字段的 .tres 写法
  - Pattern: `resources/world/samples/mvp_event_market_disturbance.tres` - 复杂字典数组样例

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/resources/world_crafting_recipe_data.gd")` valid=true
  - [ ] `godot_validate(scriptPath="scripts/resources/world_loot_table_data.gd")` valid=true
  - [ ] 4个样例 .tres 加载无报错

  **QA Scenarios**:
  ```
  Scenario: 配方材料完整性
    Tool: godot_run_script
    Steps: 加载 mvp_recipe_healing_pill.tres，验证 materials 数组非空且每个条目含 item_id 和 quantity
    Expected: materials 至少1条，0 错误
    Evidence: .sisyphus/evidence/task-3-recipe-load.log

  Scenario: 掉落表权重验证
    Tool: godot_run_script
    Steps: 加载 mvp_loot_village.tres，验证 entries 数组中每个 weight > 0
    Expected: 所有 weight > 0，0 错误
    Evidence: .sisyphus/evidence/task-3-loot-weight.log
  ```

  **Commit**: YES | Message: `feat(data): 添加制作配方与掉落表数据资源` | Files: [scripts/resources/world_crafting_recipe_data.gd, scripts/resources/world_loot_table_data.gd, resources/world/samples/mvp_recipe_*.tres, resources/world/samples/mvp_loot_*.tres]

- [x] 4. 战斗数据类型定义

  **What to do**:
  1. 创建 `scripts/data/combatant_data.gd`（RefCounted）：
     - `character_id: String`、`name: String`、`max_hp: int`、`current_hp: int`
     - `attack: int`、`defense: int`、`speed: int`（决定先攻）
     - `equipped_techniques: Array[Dictionary]`（每个含 technique_id/current_cooldown）
     - `status_effects: Array[Dictionary]`（如 {"type": "burn", "damage_per_turn": 5, "remaining_turns": 3}）
     - `inventory_snapshot: Array[Dictionary]`（战斗中可用消耗品）
     - `is_player: bool`
  2. 创建 `scripts/data/combat_action_data.gd`（RefCounted）：
     - `action_type: String`（"technique"/"item"/"flee"）
     - `technique_id: String`（当action_type="technique"时）
     - `item_id: String`（当action_type="item"时）
     - `target_index: int`（目标在敌方的索引，0起始）
  3. 创建 `scripts/data/combat_result_data.gd`（RefCounted）：
     - `victor_id: String`、`turns_elapsed: int`
     - `loot: Array[Dictionary]`（掉落物品）
     - `combat_log: Array[String]`（逐回合文字战报）
     - `participant_states: Array[Dictionary]`（战后状态快照，含HP/状态效果）
  4. 所有类添加 `to_dict() → Dictionary` 和 `static from_dict(d) → Self` 方法（存档需要）

  **Must NOT do**:
  - 不实现 CombatManager 逻辑（那是 Task 9）
  - 不修改 NPC 行为系统

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 纯数据类定义，跟随现有 scripts/data/ 模式
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [5,9,12,17,21] | Blocked By: []

  **References**:
  - Pattern: `scripts/data/behavior_action.gd` - RefCounted 数据类 + to_dict/from_dict 模式
  - Pattern: `scripts/data/relationship_edge.gd` - 简单数据类 + 序列化
  - Pattern: `scripts/data/npc_memory_entry.gd` - 复杂字段 + 序列化

  **Acceptance Criteria**:
  - [ ] 3个 .gd 文件 `godot_validate` 全部 valid=true
  - [ ] 每个类有 to_dict/from_dict 且往返序列化一致

  **QA Scenarios**:
  ```
  Scenario: 序列化往返一致性
    Tool: godot_run_script
    Steps: 创建 CombatantData(name="测试", max_hp=100, attack=20) → to_dict → from_dict → 比较字段
    Expected: 所有字段值一致，0 差异
    Evidence: .sisyphus/evidence/task-4-combat-serialization.log

  Scenario: CombatResult序列化
    Tool: godot_run_script
    Steps: 创建 CombatResultData(victor_id="char_1", turns_elapsed=5, combat_log=["回合1:..."]) → to_dict → from_dict
    Expected: 完整还原，combat_log 数组长度一致
    Evidence: .sisyphus/evidence/task-4-result-serialization.log
  ```

  **Commit**: YES | Message: `feat(data): 添加战斗数据类型CombatantData/CombatAction/CombatResult` | Files: [scripts/data/combatant_data.gd, scripts/data/combat_action_data.gd, scripts/data/combat_result_data.gd]

- [x] 5. WorldDataCatalog 扩展（items/techniques/recipes/loot_tables）

  **What to do**:
  1. 修改 `scripts/resources/world_data_catalog.gd`，新增导出数组：
     - `items: Array[WorldItemData] = []`
     - `techniques: Array[WorldTechniqueData] = []`
     - `crafting_recipes: Array[WorldCraftingRecipeData] = []`
     - `loot_tables: Array[WorldLootTableData] = []`
  2. 新增查找方法（跟随现有 find_region/find_character 模式）：
     - `find_item(id: String) -> WorldItemData`
     - `find_technique(id: String) -> WorldTechniqueData`
     - `find_recipe(id: String) -> WorldCraftingRecipeData`
     - `find_loot_table(id: String) -> WorldLootTableData`
     - `get_techniques_by_sect(sect_id: String) -> Array[WorldTechniqueData]`
     - `get_items_by_type(item_type: String) -> Array[WorldItemData]`
     - `get_recipes_by_type(recipe_type: String) -> Array[WorldCraftingRecipeData]`
     - `get_loot_tables_by_region_tag(tag: String) -> Array[WorldLootTableData]`
  3. 在 `_validate()` 方法中增加对新数组的校验（非空检查、id唯一性）
  4. 更新 `resources/world/world_data_catalog.tres`，引用 Wave1 创建的样例 .tres
  5. 验证现有 find_region/find_character/find_faction 等方法不受影响

  **Must NOT do**:
  - 不删除或修改现有数组和查找方法
  - 不改变 catalog 的加载路径或格式

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: Catalog是核心数据枢纽，修改需谨慎验证现有功能不受影响
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: NO | Wave 1 (must wait for 1,2,3,4) | Blocks: [7,8,9,10,11] | Blocked By: [1,2,3,4]

  **References**:
  - Pattern: `scripts/resources/world_data_catalog.gd` - 现有数组定义、find_* 方法模式、_validate 逻辑
  - Pattern: `resources/world/world_data_catalog.tres` - catalog .tres 的引用格式
  - API/Type: Task 1 的 `WorldItemData`、Task 2 的 `WorldTechniqueData`、Task 3 的 `WorldCraftingRecipeData`/`WorldLootTableData`

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/resources/world_data_catalog.gd")` valid=true
  - [ ] `godot_validate(scenePath="resources/world/world_data_catalog.tres")` valid=true（如可校验）
  - [ ] 现有 find_region/find_character/find_faction 仍正常工作
  - [ ] 新增 find_item/find_technique/find_recipe/find_loot_table 返回正确结果

  **QA Scenarios**:
  ```
  Scenario: Catalog加载完整性
    Tool: godot_run_script
    Steps: 加载 world_data_catalog.tres，验证 items/techniques/crafting_recipes/loot_tables 数组非空，调用 find_item("item_iron_sword") 和 find_technique("technique_basic_sword")
    Expected: 返回正确 Resource，0 错误
    Evidence: .sisyphus/evidence/task-5-catalog-load.log

  Scenario: 现有功能回归
    Tool: godot_run_script
    Steps: 加载 catalog，调用 find_region/find_character/find_faction（使用现有样例 id）
    Expected: 全部返回正确结果，0 错误（确保新字段不影响旧功能）
    Evidence: .sisyphus/evidence/task-5-catalog-regression.log
  ```

  **Commit**: YES | Message: `feat(data): 扩展WorldDataCatalog支持物品/功法/配方/掉落表` | Files: [scripts/resources/world_data_catalog.gd, resources/world/world_data_catalog.tres]

- [x] 6. 统一事件总线契约定义

  **What to do**:
  1. 创建 `scripts/core/event_contracts.gd`（常量类），定义跨系统事件信号名称：
     - 物品事件: `ITEM_ACQUIRED`, `ITEM_USED`, `ITEM_EQUIPPED`, `ITEM_DROPPED`, `ITEM_CRAFTED`
     - 功法事件: `TECHNIQUE_LEARNED`, `TECHNIQUE_MEDITATED`, `TECHNIQUE_EQUIPPED`, `TECHNIQUE_SECT_RESTRICTED`
     - 战斗事件: `COMBAT_STARTED`, `COMBAT_TURN_RESOLVED`, `COMBAT_ENDED`, `COMBAT_FLED`
     - 世界事件: `TERRITORY_CHANGED`, `REGION_RESOURCE_PRODUCED`, `REGION_RESOURCE_DEPLETED`, `FACTION_INFLUENCE_CHANGED`
     - 经济事件: `TRADE_COMPLETED`, `CRAFTING_SUCCESS`, `CRAFTING_FAILURE`
  2. 创建 `scripts/core/rng_channels.gd`（RNG通道管理）：
     - 管理独立 RNG 实例：`world_rng`, `combat_rng`, `loot_rng`
     - 提供 `get_world_rng()`, `get_combat_rng()`, `get_loot_rng()` 接口
     - 支持 `seed_all(master_seed: int)` 从主种子派生子种子
     - 支持 `save_state() → Dictionary` 和 `load_state(d)` 用于存档
  3. 定义 tick 执行顺序常量 `scripts/core/tick_order.gd`：
     - `PHASE_PRODUCTION` → `PHASE_NPC_DECISION` → `PHASE_NPC_ACTION` → `PHASE_COMBAT` → `PHASE_TERRITORY` → `PHASE_CLEANUP`
  4. 所有类为纯常量/工具类，无状态副作用

  **Must NOT do**:
  - 不修改 SimulationRunner 的 advance_tick 逻辑（那在 Wave3）
  - 不修改 EventLog 的 add_event 接口

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 纯常量/工具类定义，逻辑简单
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [7,8,9,10] | Blocked By: []

  **References**:
  - Pattern: `autoload/event_log.gd` - 现有事件日志接口，新事件类型需与此兼容
  - Pattern: `scripts/sim/seeded_random.gd` - 现有 RNG 封装，新 RNG 通道需遵循此模式
  - Pattern: `scripts/sim/simulation_runner.gd:advance_tick` - 现有 tick 流程，新顺序需兼容

  **Acceptance Criteria**:
  - [ ] 3个 .gd 文件 `godot_validate` 全部 valid=true
  - [ ] rng_channels.gd 的 seed_all + save_state + load_state 往返一致

  **QA Scenarios**:
  ```
  Scenario: RNG确定性
    Tool: godot_run_script
    Steps: seed_all(42) → get_combat_rng().randi_range(1,100) → save_state → seed_all(42) → get_combat_rng().randi_range(1,100)
    Expected: 两次调用返回相同值，0 偏差
    Evidence: .sisyphus/evidence/task-6-rng-determinism.log

  Scenario: RNG通道隔离
    Tool: godot_run_script
    Steps: seed_all(42) → 调用 world_rng.randi() 5次 → 检查 combat_rng 状态未变
    Expected: combat_rng 的 save_state() 与初始 seed_all(42) 后的 combat_rng 状态一致
    Evidence: .sisyphus/evidence/task-6-rng-isolation.log
  ```

  **Commit**: YES | Message: `feat(core): 添加统一事件总线契约、RNG通道管理和tick顺序定义` | Files: [scripts/core/event_contracts.gd, scripts/core/rng_channels.gd, scripts/core/tick_order.gd]

- [x] 7. InventoryService 背包服务（Autoload）

  **What to do**:
  1. 创建 `autoload/inventory_service.gd`，注册为 Autoload（project.godot 新增 `InventoryService`）
  2. 运行时数据结构：`_inventories: Dictionary = {}`，键为 character_id，值为 `Array[Dictionary]`，每个 Dictionary 含：
     - `item_id: String`、`quantity: int`、`rarity: String`、`affixes: Array[Dictionary]`（已实例化的词条）
     - `equipped_slot: String`（空=未装备）
  3. 核心API：
     - `add_item(character_id: String, item_id: String, quantity: int, rarity: String, affixes: Array) -> bool`
     - `remove_item(character_id: String, item_id: String, quantity: int) -> bool`
     - `get_inventory(character_id: String) -> Array[Dictionary]`
     - `equip_item(character_id: String, item_id: String, slot: String) -> bool`（自动卸下同槽位旧装备）
     - `unequip_item(character_id: String, slot: String) -> bool`
     - `use_consumable(character_id: String, item_id: String) -> Dictionary`（返回效果字典）
     - `get_equipped_stats(character_id: String) -> Dictionary`（汇总所有装备属性加成）
     - `has_item(character_id: String, item_id: String, min_quantity: int) -> bool`
  4. 通过 EventLog 发出事件（ITEM_ACQUIRED/ITEM_USED/ITEM_EQUIPPED/ITEM_DROPPED）
  5. `save_state() → Dictionary` 和 `load_state(d)` 方法
  6. 绑定到 SimulationRunner：在 `setup_services` 中调用 `InventoryService.bind_catalog(catalog)`
  7. 装备槽位常量：`SLOT_WEAPON`, `SLOT_HEAD`, `SLOT_BODY`, `SLOT_ACCESSORY_1`, `SLOT_ACCESSORY_2`

  **Must NOT do**:
  - 不在 Autoload 中放业务逻辑（炼丹/炼器/交易逻辑放 scripts/services/）
  - 不修改 SimulationRunner 的现有接口签名（仅扩展调用）
  - 不修改 ui_root.gd（那是 Wave 5）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 背包服务是核心枢纽，需与多个系统交互，存档序列化复杂
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES (with #8) | Wave 2 | Blocks: [11,12,15,19] | Blocked By: [1,6]

  **References**:
  - Pattern: `autoload/location_service.gd` - Autoload 服务模式：bind_catalog/bind_runtime + 查询API
  - Pattern: `autoload/character_service.gd` - 另一个查询型 Autoload 的接口设计
  - Pattern: `autoload/save_service.gd` - save/load 流程参考
  - API/Type: `scripts/resources/world_item_data.gd:WorldItemData` - Item 定义
  - API/Type: `scripts/core/event_contracts.gd` - 事件常量
  - Integration: `scripts/sim/simulation_runner.gd:setup_services` - 需在此绑定 InventoryService

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="autoload/inventory_service.gd")` valid=true
  - [ ] add_item → get_inventory 返回正确条目
  - [ ] equip_item 自动卸下同槽位旧装备
  - [ ] get_equipped_stats 正确汇总属性加成
  - [ ] save_state → load_state 往返一致

  **QA Scenarios**:
  ```
  Scenario: 物品增删与装备
    Tool: godot_run_script
    Steps: add_item("char_1", "item_iron_sword", 1, "common", []) → equip_item("char_1", "item_iron_sword", "weapon") → get_equipped_stats("char_1") → remove_item("char_1", "item_iron_sword", 1)
    Expected: add成功; equip成功且stats含attack加成; remove后inventory为空
    Evidence: .sisyphus/evidence/task-7-inventory-basic.log

  Scenario: 装备槽替换
    Tool: godot_run_script
    Steps: add_item("char_1", "item_iron_sword", 1, "common", []) → equip("weapon") → add_item("char_1", "item_fire_sword", 1, "rare", [{"affix_id": "fire_boost"}]) → equip("weapon") → get_inventory → 检查铁剑为未装备
    Expected: 火剑在weapon槽，铁剑unequipped，0错误
    Evidence: .sisyphus/evidence/task-7-equip-replace.log

  Scenario: 存档往返
    Tool: godot_run_script
    Steps: 填充inventory → save_state → 清空 → load_state → 比较inventory内容
    Expected: 完全一致，0 差异
    Evidence: .sisyphus/evidence/task-7-inventory-save.log
  ```

  **Commit**: YES | Message: `feat(services): 添加背包服务InventoryService` | Files: [autoload/inventory_service.gd, project.godot]

- [x] 8. TechniqueService 功法服务

  **What to do**:
  1. 创建 `scripts/services/technique_service.gd`（非Autoload，由SimulationRunner持有实例）：
  2. 运行时数据：`_learned_techniques: Dictionary = {}`，键为 character_id，值为 `Array[Dictionary]`，每个含：
     - `technique_id: String`、`mastery_level: int`（熟练度0-100）、`unlocked_affixes: Array[Dictionary]`、`locked_affixes: Array[Dictionary]`
     - `equipped_slot: String`（"martial_1"/"spirit_1"/"ultimate"/"movement"/"passive_1"/"passive_2"）
  3. 核心API：
     - `learn_technique(character_id: String, technique_id: String, catalog: WorldDataCatalog) -> Dictionary`（返回 {"success": bool, "reason": String}，检查门派独占+资质要求）
     - `meditate_affix(character_id: String, technique_id: String, affix_index: int, rng: SeededRandom) -> Dictionary`（参悟：消耗灵石，随机化指定词条品质/效果）
     - `equip_technique(character_id: String, technique_id: String, slot: String) -> bool`
     - `unequip_technique(character_id: String, slot: String) -> bool`
     - `get_learned_techniques(character_id: String) -> Array[Dictionary]`
     - `get_technique_combat_skills(character_id: String) -> Array[Dictionary]`（汇总装备功法的战斗技能）
     - `check_learning_requirements(character_id: String, technique_id: String, catalog: WorldDataCatalog, character_data: Dictionary) -> Dictionary`
  4. 参悟机制实现：
     - 消耗灵石（base_value × 2）
     - 从 locked_affixes 解锁一个到 unlocked_affixes
     - 已解锁词条品质可重随机化（有概率升/降/不变）
     - 使用 loot_rng 通道保证确定性
  5. 门派独占检查：若 technique.sect_exclusive_id 非空，角色 faction_id 必须匹配
  6. 技能槽位常量：`SLOT_MARTIAL_1`, `SLOT_SPIRIT_1`, `SLOT_ULTIMATE`, `SLOT_MOVEMENT`, `SLOT_PASSIVE_1`, `SLOT_PASSIVE_2`
  7. `save_state/load_state` 序列化方法

  **Must NOT do**:
  - 不修改 HumanCultivationProgress（那是 Task 16）
  - 不修改 NpcBehaviorLibrary（那是 Task 12）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 功法系统涉及词条参悟、门派门禁、技能槽位等复杂交互
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES (with #7) | Wave 2 | Blocks: [11,12,16,20] | Blocked By: [2,6]

  **References**:
  - Pattern: `scripts/npc/relationship_network.gd` - 非Autoload服务模式：由SimulationRunner持有，有save_state/load_state
  - Pattern: `scripts/npc/npc_memory_system.gd` - 同上，非Autoload服务 + 序列化
  - API/Type: `scripts/resources/world_technique_data.gd:WorldTechniqueData` - 功法定义
  - API/Type: `scripts/data/technique_affix.gd:TechniqueAffix` - 词条定义
  - API/Type: `scripts/core/event_contracts.gd` - TECHNIQUE_LEARNED/MEDITATED/EQUIPPED/SECT_RESTRICTED
  - API/Type: `scripts/core/rng_channels.gd` - loot_rng 通道

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/services/technique_service.gd")` valid=true
  - [ ] learn_technique 门派独占正确阻断/放行
  - [ ] meditate_affix 消耗灵石且词条品质变化
  - [ ] get_technique_combat_skills 返回装备功法的战斗技能汇总
  - [ ] save_state/load_state 往返一致

  **QA Scenarios**:
  ```
  Scenario: 门派独占门禁
    Tool: godot_run_script
    Steps: learn_technique(char_A faction="faction_azure_sect", technique_id="technique_sect_exclusive_azure_sword") → learn_technique(char_B faction="faction_other", same technique)
    Expected: char_A 成功，char_B 失败且 reason="SECT_RESTRICTED"
    Evidence: .sisyphus/evidence/task-8-sect-gate.log

  Scenario: 参悟词条
    Tool: godot_run_script
    Steps: learn_technique → 检查 locked_affixes 数量 → meditate_affix(index=0, seed=42) → 检查 unlocked_affixes 增加且灵石减少
    Expected: 解锁一个词条，灵石扣除 = technique.base_value × 2
    Evidence: .sisyphus/evidence/task-8-meditate.log

  Scenario: 存档往返
    Tool: godot_run_script
    Steps: 学习2个功法+参悟1次 → save_state → 清空 → load_state → 比较
    Expected: learned_techniques 完全一致，0 差异
    Evidence: .sisyphus/evidence/task-8-technique-save.log
  ```

  **Commit**: YES | Message: `feat(services): 添加功法服务TechniqueService含参悟与门派门禁` | Files: [scripts/services/technique_service.gd]

- [x] 9. CombatManager 文字回合制战斗引擎

  **What to do**:
  1. 创建 `scripts/combat/combat_manager.gd`（RefCounted，由SimulationRunner持有）：
  2. 战斗流程：
     - `start_combat(participants: Array[CombatantData], rng: SeededRandom) -> CombatResultData`
     - 回合循环（最多30回合）：
       1. 按 speed 排序决定行动顺序
       2. 每个参战者选择行动（NPC由决策引擎自动选择，玩家由UI选择）
       3. 结算行动：伤害 = (attacker.attack × technique_power - defender.defense) × element_modifier × rng_variance(0.8~1.2)
       4. 应用状态效果（灼烧/中毒/冰冻等 tick 伤害/效果）
       5. 检查胜负条件（HP<=0 或逃跑成功）
     - 胜负确定后：生成掉落（从loot_rng + loot_table），构建 CombatResultData
  3. 元素克制表：火克风、风克雷、雷克水、水克火、土木互克，克制=1.3倍，被克=0.7倍
  4. NPC战斗AI（简化版）：
     - 优先使用克制对方元素的功法
     - HP<30%时优先使用回复消耗品
     - 无可用功法则普通攻击
  5. `resolve_npc_combat_only(participants, rng) -> CombatResultData`：纯NPC战斗（自动双方决策）
  6. 战斗日志格式："[回合N] {攻击者} 使用 {功法名} 对 {目标} 造成 {伤害} 点{元素}伤害"
  7. `save_state/load_state` 方法（保存进行中的战斗状态）

  **Must NOT do**:
  - 不创建战斗UI（那是 Task 21）
  - 不修改 NPC DecisionEngine 的冲突评分逻辑（那是 Task 13）
  - 不在 CombatManager 中直接操作 InventoryService（战斗结果通过返回值交给调用方处理）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 战斗引擎是核心循环，伤害公式/元素克制/状态效果/确定性需精心设计
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES (with #10) | Wave 2 | Blocks: [12,13,17,21] | Blocked By: [2,4,6]

  **References**:
  - API/Type: `scripts/data/combatant_data.gd:CombatantData` - 参战者数据
  - API/Type: `scripts/data/combat_action_data.gd:CombatActionData` - 行动数据
  - API/Type: `scripts/data/combat_result_data.gd:CombatResultData` - 结果数据
  - API/Type: `scripts/resources/world_technique_data.gd:WorldTechniqueData.combat_skills` - 功法战斗技能
  - API/Type: `scripts/core/rng_channels.gd` - combat_rng/loot_rng 通道
  - API/Type: `scripts/core/event_contracts.gd` - COMBAT_STARTED/TURN_RESOLVED/ENDED 事件
  - Pattern: `scripts/sim/seeded_random.gd` - 确定性 RNG 使用方式

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/combat/combat_manager.gd")` valid=true
  - [ ] 同seed 20次 resolve_npc_combat_only 结果逐行一致
  - [ ] 元素克制正确（火>风>雷>水>火）
  - [ ] HP<=0 立即结束战斗
  - [ ] 掉落从 loot_table 正确采样

  **QA Scenarios**:
  ```
  Scenario: 战斗确定性
    Tool: godot_run_script
    Steps: 创建两个 CombatantData(A:atk=50,hp=200,spd=30; B:atk=40,hp=180,spd=25)，seed=42 → resolve_npc_combat_only → 记录 combat_log → 重复20次
    Expected: 20次 combat_log 逐行完全一致，0 偏差
    Evidence: .sisyphus/evidence/task-9-combat-determinism.log

  Scenario: 元素克制
    Tool: godot_run_script
    Steps: 火属性攻击者(technique element=fire) 对 风属性防御者 → 计算伤害 → 对比 无属性克制基准伤害
    Expected: 克制伤害 ≈ 基准 × 1.3（允许RNG浮动内）
    Evidence: .sisyphus/evidence/task-9-element-advantage.log

  Scenario: 战斗结束条件
    Tool: godot_run_script
    Steps: 创建极不平衡战斗(A:atk=999,hp=999 vs B:atk=1,hp=10) → resolve_npc_combat_only
    Expected: 1回合内结束，B.hp<=0，victor_id=A
    Evidence: .sisyphus/evidence/task-9-combat-end.log
  ```

  **Commit**: YES | Message: `feat(combat): 添加文字回合制战斗引擎CombatManager` | Files: [scripts/combat/combat_manager.gd]

- [x] 10. WorldDynamicsService 世界动态服务

  **What to do**:
  1. 创建 `scripts/services/world_dynamics_service.gd`（由SimulationRunner持有）：
  2. 区域资源系统：
     - `_region_states: Dictionary = {}`，键为 region_id，值为：
       - `resource_stockpiles: Dictionary`（如 {"spirit_stone": 100, "herb": 50}）
       - `production_rates: Dictionary`（如 {"spirit_stone": 10/day, "herb": 5/day}）
       - `controlling_faction_id: String`
       - `faction_modifier: float`（势力控制倍率，1.0=正常，1.5=强控，0.5=弱控）
       - `danger_level: float`（0.0-1.0，影响采集安全和NPC行为）
       - `population: int`（区域人口）
  3. 核心API：
     - `init_region_states(regions: Array, rng: SeededRandom)` - 从世界生成初始化
     - `advance_production()` - 每日资源产出（production_rate × faction_modifier × rng_variance）
     - `advance_consumption(population_modifier: float)` - 每日资源消耗
     - `gather_resource(region_id: String, resource_type: String, amount: int) -> bool` - 采集
     - `contest_territory(region_id: String, challenger_faction_id: String, combat_result: CombatResultData)` - 领地争夺
     - `update_faction_influence(faction_id: String, delta: float)` - 更新势力影响力
     - `get_region_state(region_id: String) -> Dictionary`
     - `get_all_region_states() -> Dictionary`
     - `get_faction_territories(faction_id: String) -> Array[String]`
  4. 领地变更逻辑：
     - 战胜方获得领地，controlling_faction_id 更新
     - 势力影响力影响 faction_modifier
     - 领地变更触发 TERRITORY_CHANGED 事件
     - 次tick起资源产出按新归属 faction_modifier 计算
  5. 势力繁荣/衰落：
     - 资源充足 → 影响力缓增
     - 资源耗尽 → 影响力缓减
     - 影响力过低 → 可能失去边缘领地
  6. `save_state/load_state` 序列化

  **Must NOT do**:
  - 不修改 LocationService 的现有接口
  - 不在 advance_production 中直接调用 InventoryService

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 多系统交互，需理解区域/势力/资源的经济闭环
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES (with #9) | Wave 2 | Blocks: [14,22] | Blocked By: [5,6]

  **References**:
  - Pattern: `scripts/npc/relationship_network.gd` - 非Autoload服务 + save_state/load_state 模式
  - Pattern: `scripts/resources/world_region_data.gd:WorldRegionData` - 区域模板字段（resource_tags/danger_tags/controlling_faction_id）
  - Pattern: `scripts/resources/world_faction_data.gd:WorldFactionData` - 势力字段（influence/territory_region_ids）
  - API/Type: `scripts/core/event_contracts.gd` - TERRITORY_CHANGED/REGION_RESOURCE_* 事件
  - API/Type: `scripts/core/tick_order.gd` - PHASE_PRODUCTION/PHASE_TERRITORY 顺序

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/services/world_dynamics_service.gd")` valid=true
  - [ ] advance_production 正确产出资源（stockpile 增加）
  - [ ] gather_resource 减少库存，库存不足时返回 false
  - [ ] contest_territory 更新 controlling_faction_id 且触发事件
  - [ ] 1000tick仿真无经济崩盘（stockpile 非负，货币增长<5%）

  **QA Scenarios**:
  ```
  Scenario: 资源产出与消耗
    Tool: godot_run_script
    Steps: init_region_states → 连续100次 advance_production → 连续100次 advance_consumption(0.5) → 检查 stockpile 变化趋势
    Expected: 产出期stockpile递增；消耗期递减但始终非负（因consumption_rate < production_rate）
    Evidence: .sisyphus/evidence/task-10-resource-cycle.log

  Scenario: 领地变更联动
    Tool: godot_run_script
    Steps: contest_territory(region_1, challenger="faction_B", combat_result={victor_id="char_B"}) → get_region_state(region_1).controlling_faction_id → advance_production → 检查faction_modifier变化
    Expected: controlling_faction_id = "faction_B"，次tick产出按新倍率
    Evidence: .sisyphus/evidence/task-10-territory-change.log

  Scenario: 经济稳定性
    Tool: godot_run_script
    Steps: init_region_states(seed=42) → 1000tick (production + consumption) → 统计总货币增长率和各区域stockpile
    Expected: 总货币增长率 < 5%，0 个区域 stockpile 为负
    Evidence: .sisyphus/evidence/task-10-economy-stability.log
  ```

  **Commit**: YES | Message: `feat(services): 添加世界动态服务WorldDynamicsService含资源产出与领地变迁` | Files: [scripts/services/world_dynamics_service.gd]

- [x] 11. WorldGenerator 扩展（物品/功法/掉落/动态区域）

  **What to do**:
  1. 修改 `scripts/world/world_generator.gd`：
     - 将 `generate_cultivation_methods(rng)` 从产出简单字典改为产出 WorldTechniqueData Resource 实例（优先从 catalog 读取，回退到程序化生成）
     - 新增 `generate_items(rng, catalog) -> Array[Dictionary]`：基于 catalog 中的 item 模板生成散布在世界中的物品实例（含随机词条）
     - 新增 `generate_loot_instances(rng, catalog) -> Dictionary`：为每个区域生成关联的 loot_table_id
     - 扩展 `generate_regions(rng)` 的输出，增加 `production_rates`/`initial_stockpiles` 字段
     - 新增 `generate_technique_affixes(rng, technique: WorldTechniqueData) -> Array[Dictionary]`：为功法生成随机词条实例
     - 新增 `generate_item_affixes(rng, item: WorldItemData) -> Array[Dictionary]`：为物品生成随机词条实例
  2. 物品/功法生成规则：
     - 品质权重：common=50%, uncommon=30%, rare=12%, epic=5%, legendary=2%, mythic=1%
     - 词条品质跟随物品品质（高品质更多词条槽+更高品质词条）
     - 门派独占功法只在对应门派所在区域生成
  3. 在 generate() 返回值中增加 `items`/`loot_assignments`/`region_dynamics_init` 字段
  4. 保持与现有 generate() 返回格式的向后兼容（新增字段，不删除旧字段）

  **Must NOT do**:
  - 不删除 generate_cultivation_methods 的旧字典格式（保留兼容，新代码优先用 Resource）
  - 不修改 SimulationRunner 的 bootstrap 流程（那是 Task 14/15 接入点）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 世界生成器是所有内容的源头，修改需确保确定性+兼容性
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: [14,15] | Blocked By: [1,2,3,5,7,8]

  **References**:
  - Existing: `scripts/world/world_generator.gd` - 完整的世界生成器代码，需扩展
  - Pattern: `scripts/world/world_generator.gd:generate_cultivation_methods` - 现有功法生成，需改为Resource
  - Pattern: `scripts/world/world_generator.gd:generate_regions` - 现有区域生成，需增加资源产出字段
  - Pattern: `scripts/world/world_generator.gd:generate_resources` - 现有资源生成（字典），需关联到 ItemData
  - API/Type: `scripts/resources/world_item_data.gd:WorldItemData` - 物品定义
  - API/Type: `scripts/resources/world_technique_data.gd:WorldTechniqueData` - 功法定义
  - API/Type: `scripts/data/technique_affix.gd:TechniqueAffix` - 词条定义

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/world/world_generator.gd")` valid=true
  - [ ] 固定seed(42) 两次 generate() 的 items/techniques 字段一致
  - [ ] 生成的功法包含词条实例，门派独占功法只在对应区域出现
  - [ ] 区域输出包含 production_rates/initial_stockpiles

  **QA Scenarios**:
  ```
  Scenario: 生成确定性
    Tool: godot_run_script
    Steps: seed=42 → generate() → 记录 items/techniques/region_dynamics_init → seed=42 → generate() → 比较
    Expected: 两次结果完全一致，0 偏差
    Evidence: .sisyphus/evidence/task-11-gen-determinism.log

  Scenario: 品质分布
    Tool: godot_run_script
    Steps: seed=42 → generate() → 统计 items 的 rarity 分布 → 检查 common>uncommon>rare>epic>legendary>mythic
    Expected: 品质排序符合权重，无 mythic 超过 legendary 的情况
    Evidence: .sisyphus/evidence/task-11-rarity-dist.log

  Scenario: 门派独占生成位置
    Tool: godot_run_script
    Steps: 生成含 sect_exclusive 的功法 → 检查其所在区域是否包含对应 sect 的 faction
    Expected: 门派独占功法100%在对应门派领地区域内
    Evidence: .sisyphus/evidence/task-11-sect-location.log
  ```

  **Commit**: YES | Message: `feat(world): 扩展WorldGenerator支持物品/功法/掉落/动态区域生成` | Files: [scripts/world/world_generator.gd]

- [x] 12. NPC行为库扩展 + 数据驱动迁移

  **What to do**:
  1. 修改 `scripts/npc/npc_behavior_library.gd`：
     - 保留 BEHAVIOR_DEFS 作为兜底，新增 `_custom_behaviors: Array[BehaviorAction] = []` 字段（可从资源加载）
     - 新增物品相关行为（加入 BEHAVIOR_DEFS）：
       - `gather_resource`: 采集当前区域资源，条件 has_region_resource，压力满足 NEED_RESOURCE
       - `trade_item`: 与NPC交易物品，条件 has_gold，压力满足 NEED_RESOURCE
       - `use_consumable`: 使用消耗品，条件 has_consumable，压力满足 NEED_SURVIVAL
     - 新增功法相关行为：
       - `learn_technique`: 学习可用功法，条件 has_technique_opportunity，压力满足 NEED_REPUTATION
       - `practice_technique`: 练习已学功法，条件 has_technique，压力满足 NEED_REPUTATION
       - `meditate_affix`: 参悟功法词条，条件 has_gold(灵石)，压力满足 NEED_REPUTATION
     - 新增战斗相关行为：
       - `challenge_npc`: 挑战NPC战斗，条件 has_grudge OR need_resource(掠夺)，压力满足 NEED_REPUTATION/NEED_RESOURCE
       - `defend_territory`: 防卫领地，条件 own_territory_threatened，压力满足 NEED_BELONGING
     - 新增领地相关行为：
       - `expand_territory`: 扩张领地，条件 faction_strong AND adjacent_unclaimed，压力满足 NEED_BELONGING
       - `contest_region`: 争夺区域，条件 faction_vs_rival_in_region，压力满足 NEED_BELONGING
  2. 每个新行为的 pressure_deltas/favor_deltas/conditions/weight/cooldown_hours 需具体定义
  3. 新增 `load_custom_behaviors(catalog: WorldDataCatalog)` 方法，从 catalog 或 .tres 加载自定义行为定义（迁移路径）
  4. 扩展 `get_available_behaviors` 返回合并后的行为列表（内置 + 自定义）

  **Must NOT do**:
  - 不删除现有 BEHAVIOR_DEFS 中的行为
  - 不修改 NpcDecisionEngine 的评分算法（那是 Task 13）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 行为库是NPC AI的核心，需平衡新行为与现有评分逻辑
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: [13] | Blocked By: [7,8,9]

  **References**:
  - Existing: `scripts/npc/npc_behavior_library.gd` - 完整行为库代码，BEHAVIOR_DEFS 结构
  - Pattern: `scripts/data/behavior_action.gd:BehaviorAction` - 行为数据结构（action_id/pressure_deltas/conditions/weight/cooldown_hours）
  - Pattern: `scripts/npc/npc_decision_engine.gd` - 行为评分逻辑，新行为需与之兼容
  - API/Type: `autoload/inventory_service.gd` - 物品行为需交互的接口
  - API/Type: `scripts/services/technique_service.gd` - 功法行为需交互的接口
  - API/Type: `scripts/combat/combat_manager.gd` - 战斗行为需交互的接口

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/npc/npc_behavior_library.gd")` valid=true
  - [ ] 新增的10个行为在 get_available_behaviors 中正确返回
  - [ ] 新行为与现有行为的 conditions/weight 格式一致
  - [ ] load_custom_behaviors 从 catalog 加载自定义行为不崩溃

  **QA Scenarios**:
  ```
  Scenario: 新行为可用性
    Tool: godot_run_script
    Steps: 创建 BehaviorLibrary → get_available_behaviors(character with needs/has_technique=true) → 检查返回列表包含 gather_resource/learn_technique/challenge_npc
    Expected: 新行为在结果中，条件匹配正确
    Evidence: .sisyphus/evidence/task-12-new-behaviors.log

  Scenario: 自定义行为加载
    Tool: godot_run_script
    Steps: load_custom_behaviors(catalog) → get_available_behaviors → 检查列表长度 > BEHAVIOR_DEFS.length
    Expected: 自定义行为合并成功，0 错误
    Evidence: .sisyphus/evidence/task-12-custom-behaviors.log
  ```

  **Commit**: YES | Message: `feat(npc): 扩展NPC行为库含物品/功法/战斗/领地行为与数据驱动迁移` | Files: [scripts/npc/npc_behavior_library.gd]

- [x] 13. NPC决策引擎集成（新行为评分+战斗接入）

  **What to do**:
  1. 修改 `scripts/npc/npc_decision_engine.gd`：
     - 确保评分算法能处理新增行为的 conditions 格式（has_region_resource, has_technique_opportunity, has_grudge, own_territory_threatened, faction_strong, faction_vs_rival_in_region, adjacent_unclaimed）
     - 新增条件检查辅助方法：
       - `_check_has_region_resource(character: Dictionary, condition: Dictionary) -> bool`
       - `_check_has_technique_opportunity(character: Dictionary, condition: Dictionary) -> bool`
       - `_check_has_grudge(character: Dictionary, condition: Dictionary) -> bool`
       - `_check_own_territory_threatened(character: Dictionary, condition: Dictionary) -> bool`
       - `_check_faction_strong(character: Dictionary, condition: Dictionary) -> bool`
       - `_check_faction_vs_rival_in_region(character: Dictionary, condition: Dictionary) -> bool`
       - `_check_adjacent_unclaimed(character: Dictionary, condition: Dictionary) -> bool`
  2. 修改 SimulationRunner 的 `_apply_npc_decision`：
     - 当选中的行为是 challenge_npc → 调用 CombatManager.resolve_npc_combat_only → 记录战斗结果 → 更新关系/记忆
     - 当选中行为是 contest_region → 调用 WorldDynamicsService.contest_territory
     - 当选中行为是 gather_resource → 调用 WorldDynamicsService.gather_resource + InventoryService.add_item
     - 当选中行为是 learn_technique → 调用 TechniqueService.learn_technique
     - 当选中行为是 trade_item → 简化交易逻辑（消耗灵石+获得物品）
  3. 修改 SimulationRunner 的 advance_tick 按照 tick_order.gd 定义的分阶段顺序执行

  **Must NOT do**:
  - 不修改评分权重算法的核心逻辑（仅扩展条件检查）
  - 不在决策引擎中直接实现交易/战斗逻辑（通过服务调用）

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 需要理解 NPC 决策+仿真推进+多服务交互
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: [] | Blocked By: [12]

  **References**:
  - Existing: `scripts/npc/npc_decision_engine.gd` - 完整决策引擎代码
  - Existing: `scripts/sim/simulation_runner.gd:_apply_npc_decision` - 行为应用逻辑
  - Existing: `scripts/sim/simulation_runner.gd:advance_tick` - tick推进流程
  - API/Type: `scripts/combat/combat_manager.gd` - 战斗接口
  - API/Type: `scripts/services/world_dynamics_service.gd` - 世界动态接口
  - API/Type: `scripts/services/technique_service.gd` - 功法接口
  - API/Type: `autoload/inventory_service.gd` - 背包接口
  - API/Type: `scripts/core/tick_order.gd` - tick执行顺序常量

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/npc/npc_decision_engine.gd")` valid=true
  - [ ] `godot_validate(scriptPath="scripts/sim/simulation_runner.gd")` valid=true
  - [ ] NPC能选中 gather_resource/learn_technique/challenge_npc 等新行为
  - [ ] challenge_npc 行为触发 CombatManager 战斗
  - [ ] advance_tick 按 PHASE 顺序执行

  **QA Scenarios**:
  ```
  Scenario: NPC采集资源
    Tool: godot_run_script
    Steps: 创建有资源区域+角色NEED_RESOURCE高 → advance_tick → 检查 InventoryService 和 WorldDynamicsService 变化
    Expected: 角色inventory增加资源，区域stockpile减少
    Evidence: .sisyphus/evidence/task-13-npc-gather.log

  Scenario: NPC战斗触发
    Tool: godot_run_script
    Steps: 创建两个有仇恨的NPC → advance_tick → 检查 EventLog 是否含 COMBAT_ENDED
    Expected: 至少一条战斗日志，关系/记忆更新
    Evidence: .sisyphus/evidence/task-13-npc-combat.log

  Scenario: Tick顺序正确
    Tool: godot_run_script
    Steps: advance_tick → 检查 EventLog 中事件的发生顺序
    Expected: PRODUCTION类事件在COMBAT类之前，TERRITORY类在最后
    Evidence: .sisyphus/evidence/task-13-tick-order.log
  ```

  **Commit**: YES | Message: `feat(npc): 集成NPC决策引擎含新行为评分、战斗接入与tick顺序` | Files: [scripts/npc/npc_decision_engine.gd, scripts/sim/simulation_runner.gd]

- [x] 14. 区域动态逻辑实现

  **What to do**:
  1. 在 SimulationRunner 中集成 WorldDynamicsService：
     - `bootstrap_from_creation` 中调用 `WorldDynamicsService.init_region_states(world_gen.region_dynamics_init, rng)`
     - `advance_tick` 中按 tick_order 调用 `advance_production`/`advance_consumption`
  2. 实现区域资源与NPC行为的联动：
     - NPC在区域采集 → WorldDynamicsService.gather_resource → InventoryService.add_item
     - 区域资源耗尽 → danger_level上升 → NPC行为避让
     - 区域资源丰富 → 吸引NPC聚集
  3. 实现宗门势力与领地联动：
     - NPC contest_region 成功 → WorldDynamicsService.contest_territory → 控制权变更
     - 势力影响力变化 → WorldDynamicsService.update_faction_influence
     - 边缘领地可能自动脱离（影响力过低时）
  4. 区域人口与资源消耗联动：
     - 人口越多 → 消耗越大
     - 资源不足 → 人口外迁（减少）
  5. 连接 LocationService：区域状态查询接口供 UI 使用

  **Must NOT do**:
  - 不修改 LocationService 的现有接口
  - 不在 SimulationRunner 中硬编码区域逻辑（全部通过 WorldDynamicsService）

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 多系统联动，需整合区域/势力/资源/NPC行为
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES (with #13) | Wave 3 | Blocks: [22] | Blocked By: [10,11]

  **References**:
  - Existing: `scripts/sim/simulation_runner.gd:bootstrap_from_creation` - 世界初始化入口
  - Existing: `scripts/sim/simulation_runner.gd:advance_tick` - tick推进入口
  - API/Type: `scripts/services/world_dynamics_service.gd` - 全部API
  - API/Type: `autoload/inventory_service.gd:add_item` - 物品发放
  - API/Type: `autoload/location_service.gd` - 区域查询
  - API/Type: `scripts/core/tick_order.gd` - PHASE_PRODUCTION/PHASE_TERRITORY

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/sim/simulation_runner.gd")` valid=true
  - [ ] bootstrap 后区域有初始 stockpile 和 production_rates
  - [ ] advance_tick 后区域 stockpile 变化（生产+消耗）
  - [ ] 领地变更后次tick产出倍率变化

  **QA Scenarios**:
  ```
  Scenario: 完整区域循环
    Tool: godot_run_script
    Steps: bootstrap_from_creation(seed=42) → 连续10次 advance_tick → 检查每个区域的 resource_stockpiles 变化趋势
    Expected: 产出>消耗的区域stockpile递增，产出<消耗的区域递减，0 个负值
    Evidence: .sisyphus/evidence/task-14-region-cycle.log

  Scenario: 领地争夺联动
    Tool: godot_run_script
    Steps: 手动触发 contest_territory → advance_tick → 检查新 controlling_faction 的区域产出变化
    Expected: 产出倍率变更为新 faction_modifier
    Evidence: .sisyphus/evidence/task-14-territory-dynamics.log
  ```

  **Commit**: YES | Message: `feat(world): 实现区域动态逻辑含资源循环与领地争夺联动` | Files: [scripts/sim/simulation_runner.gd]

- [x] 15. 玩家运行时扩展（inventory/equipment/techniques/combat_stats）

  **What to do**:
  1. 修改 `scripts/modes/human/human_opening_builder.gd`，在构建玩家初始状态时添加：
     - `inventory: Array[Dictionary] = []`（通过 InventoryService 初始化）
     - `equipment: Dictionary = {}`（{"weapon": null, "head": null, "body": null, "accessory_1": null, "accessory_2": null}）
     - `learned_techniques: Array[Dictionary] = []`（通过 TechniqueService 初始化）
     - `technique_slots: Dictionary = {}`（{"martial_1": null, "spirit_1": null, "ultimate": null, "movement": null, "passive_1": null, "passive_2": null}）
     - `combat_stats: Dictionary = {"max_hp": 100, "attack": 10, "defense": 5, "speed": 10}`（基础值，受装备/功法加成）
  2. 修改 `scripts/modes/human/human_mode_runtime.gd`，在 advance_day 中：
     - 计算装备属性加成并更新 combat_stats
     - 计算功法效果加成并更新 combat_stats
     - 检查装备耐久（如有）和消耗品效果衰减
  3. 初始装备/功法：根据角色创建选项（opening_type）给予不同的起始物品/功法

  **Must NOT do**:
  - 不修改 HumanCultivationProgress 的突破逻辑（那是 Task 16）
  - 不创建新UI（那是 Wave 5）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 玩家运行时是所有玩家交互的起点，需与多个服务正确对接
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: [16,17,18,19] | Blocked By: [7,11]

  **References**:
  - Existing: `scripts/modes/human/human_opening_builder.gd` - 玩家初始状态构建
  - Existing: `scripts/modes/human/human_mode_runtime.gd` - 人类模式推进
  - API/Type: `autoload/inventory_service.gd` - 背包接口
  - API/Type: `scripts/services/technique_service.gd` - 功法接口
  - API/Type: `scripts/data/combatant_data.gd:CombatantData` - 战斗属性结构

  **Acceptance Criteria**:
  - [ ] 玩家初始状态包含 inventory/equipment/learned_techniques/technique_slots/combat_stats
  - [ ] 装备加成正确反映到 combat_stats
  - [ ] 功法效果正确反映到 combat_stats

  **QA Scenarios**:
  ```
  Scenario: 初始状态完整性
    Tool: godot_run_script
    Steps: 创建新角色(opening_type="warrior") → 检查 player runtime 包含所有新字段且非null
    Expected: inventory非空（含初始装备），combat_stats.attack > 10（装备加成）
    Evidence: .sisyphus/evidence/task-15-player-init.log

  Scenario: 属性加成计算
    Tool: godot_run_script
    Steps: 玩家装备攻击+10武器+防御+5防具 → 计算 combat_stats → 对比无装备基础值
    Expected: attack = base + 10, defense = base + 5
    Evidence: .sisyphus/evidence/task-15-stat-bonus.log
  ```

  **Commit**: YES | Message: `feat(player): 扩展玩家运行时含背包/装备/功法/战斗属性` | Files: [scripts/modes/human/human_opening_builder.gd, scripts/modes/human/human_mode_runtime.gd]

- [x] 16. 修炼系统+功法集成

  **What to do**:
  1. 修改 `scripts/modes/human/human_cultivation_progress.gd`：
     - 修炼速度受装备功法影响（passive_method 加成）
     - 突破时检查是否有可用功法（有功法 → 突破成功率+10%）
     - 突破成功后可领悟功法新词条（自动 meditate_affix 一次）
     - 修炼事件日志增加功法信息
  2. 修改 `scripts/modes/human/human_cultivation_gate.gd`：
     - 接触功法门槛（apply_action）时，若已有门派功法 → 接触分数加成
     - 信仰接触时可获得门派独占功法的机会
     - opportunity_unlocked 时触发 TechniqueService.learn_technique

  **Must NOT do**:
  - 不修改突破核心算法（仅加成/加日志）

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: 修炼是核心循环，功法集成需平衡突破概率
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES (with #17, #18) | Wave 4 | Blocks: [20] | Blocked By: [8,15]

  **References**:
  - Existing: `scripts/modes/human/human_cultivation_progress.gd` - 修炼进度全部逻辑
  - Existing: `scripts/modes/human/human_cultivation_gate.gd` - 门槛/机会逻辑
  - API/Type: `scripts/services/technique_service.gd` - 功法学习/参悟接口

  **Acceptance Criteria**:
  - [ ] 有功法时突破成功率比无功法高
  - [ ] 突破成功后自动领悟词条
  - [ ] 门派功法对信仰接触有加成

  **QA Scenarios**:
  ```
  Scenario: 功法对突破加成
    Tool: godot_run_script
    Steps: 创建两个角色(有功法 vs 无功法) → 各尝试突破100次(固定seed) → 统计成功率
    Expected: 有功法角色成功率 > 无功法角色
    Evidence: .sisyphus/evidence/task-16-cultivation-bonus.log

  Scenario: 门派功法触发
    Tool: godot_run_script
    Steps: 角色信仰接触+有门派功法 → apply_action → 检查 opportunity_unlocked 和 TechniqueService
    Expected: opportunity_unlocked=true, TechniqueService.learn_technique 被调用
    Evidence: .sisyphus/evidence/task-16-gate-technique.log
  ```

  **Commit**: YES | Message: `feat(cultivation): 集成修炼系统与功法加成/领悟机制` | Files: [scripts/modes/human/human_cultivation_progress.gd, scripts/modes/human/human_cultivation_gate.gd]

- [x] 17. 玩家战斗参与流程

  **What to do**:
  1. 在 SimulationRunner 中新增玩家战斗入口：
     - 当玩家遭遇 conflict 行为或主动挑战NPC → 暂停自动推进 → 进入战斗状态
     - 构建 CombatantData（从玩家 runtime + 装备/功法加成计算属性）
     - 战斗通过 CombatManager 逐回合推进
     - 每回合玩家选择行动（通过 UI → 信号 → SimulationRunner → CombatManager）
     - 战斗结束 → 应用结果（掉落→InventoryService，经验→修炼进度，关系更新→RelationshipNetwork）
  2. 战斗结果处理：
     - 胜利：获得掉落 + 好感变化(仇人-10) + 修炼经验
     - 失败：损失部分灵石 + 好感变化(仇人+10) + HP未完全恢复
     - 逃跑：无损失但触发逃跑事件
  3. 新增 `RunState.sub_phase` 值：`"combat"` 表示战斗中

  **Must NOT do**:
  - 不创建战斗UI（那是 Task 21）
  - 不修改 CombatManager 核心逻辑

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 战斗参与流程涉及 SimulationRunner 状态机+UI信号+多服务交互
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES (with #16, #18) | Wave 4 | Blocks: [21] | Blocked By: [9,15]

  **References**:
  - Existing: `scripts/sim/simulation_runner.gd` - 需在此添加战斗入口
  - Existing: `autoload/run_state.gd` - sub_phase 状态管理
  - API/Type: `scripts/combat/combat_manager.gd` - 战斗引擎接口
  - API/Type: `scripts/data/combat_result_data.gd` - 战斗结果处理

  **Acceptance Criteria**:
  - [ ] 玩家可进入战斗状态（sub_phase="combat"）
  - [ ] 战斗结束后掉落进入玩家背包
  - [ ] 战斗结束后关系/记忆更新

  **QA Scenarios**:
  ```
  Scenario: 玩家战斗完整流程
    Tool: godot_run_script
    Steps: 创建玩家+NPC → 触发战斗 → 玩家自动选择攻击(模拟) → 战斗结束 → 检查 InventoryService(掉落) + RelationshipNetwork(关系变化)
    Expected: 掉落物品在背包中，关系edge更新
    Evidence: .sisyphus/evidence/task-17-player-combat.log

  Scenario: 战斗失败处理
    Tool: godot_run_script
    Steps: 极弱玩家 vs 极强NPC → 战斗 → 失败 → 检查灵石减少 + 关系恶化
    Expected: 灵石减少，好感下降
    Evidence: .sisyphus/evidence/task-17-combat-loss.log
  ```

  **Commit**: YES | Message: `feat(combat): 添加玩家战斗参与流程含结果处理与状态管理` | Files: [scripts/sim/simulation_runner.gd, autoload/run_state.gd]

- [x] 18. 炼丹炼器制作系统实现

  **What to do**:
  1. 创建 `scripts/services/crafting_service.gd`（RefCounted，由SimulationRunner持有）：
  2. 核心API：
     - `craft_item(character_id: String, recipe_id: String, catalog: WorldDataCatalog, rng: SeededRandom) -> Dictionary`
       - 检查材料是否足够（InventoryService.has_item × N）
       - 检查技艺等级（required_skill_level）
       - 计算成功率（base_rate + 材料品质加成 + 技艺等级加成）
       - 成功：消耗材料 → 生成物品（品质受材料影响）→ InventoryService.add_item
       - 失败：消耗部分材料 → 返回 {"success": false, "reason": "CRAFTING_FAILURE", "materials_lost": [...]}
     - `get_available_recipes(character_id: String, catalog: WorldDataCatalog) -> Array[WorldCraftingRecipeData]`
     - `get_recipe_details(recipe_id: String, catalog: WorldDataCatalog) -> Dictionary`
  3. 品质计算：
     - 输入材料品质加权平均 → 映射到产出品质（有随机偏移±1级，由loot_rng决定）
     - 技艺等级高 → 偏移更可能向上
  4. 通过 EventLog 发出 CRAFTING_SUCCESS/CRAFTING_FAILURE 事件
  5. `save_state/load_state` 序列化（制作技艺等级等）

  **Must NOT do**:
  - 不创建制作UI（那是 Task 24）
  - 不在 CraftingService 中直接修改 InventoryService 的内部数据

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 制作系统涉及材料消耗/品质计算/成功率，经济闭环关键
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES (with #16, #17) | Wave 4 | Blocks: [24] | Blocked By: [3,7,15]

  **References**:
  - API/Type: `scripts/resources/world_crafting_recipe_data.gd:WorldCraftingRecipeData` - 配方定义
  - API/Type: `autoload/inventory_service.gd` - 材料消耗/物品产出
  - API/Type: `scripts/core/rng_channels.gd` - loot_rng 通道
  - API/Type: `scripts/core/event_contracts.gd` - CRAFTING_SUCCESS/FAILURE 事件

  **Acceptance Criteria**:
  - [ ] `godot_validate(scriptPath="scripts/services/crafting_service.gd")` valid=true
  - [ ] 材料不足时 craft_item 返回 success=false
  - [ ] 制作成功后物品进入背包，材料被消耗
  - [ ] 品质受材料品质影响

  **QA Scenarios**:
  ```
  Scenario: 炼丹成功
    Tool: godot_run_script
    Steps: add_item(3灵草) → craft_item(recipe="healing_pill") → get_inventory → 检查丹药存在+灵草减少3
    Expected: 丹药在背包，灵草库存正确减少
    Evidence: .sisyphus/evidence/task-18-alchemy-success.log

  Scenario: 材料不足
    Tool: godot_run_script
    Steps: add_item(1灵草) → craft_item(recipe="healing_pill" 需要3灵草)
    Expected: 返回 {"success": false, "reason": "INSUFFICIENT_MATERIALS"}
    Evidence: .sisyphus/evidence/task-18-craft-fail.log

  Scenario: 品质继承
    Tool: godot_run_script
    Steps: 使用高品质材料(rare) → craft_item → 检查产出品质 ≥ uncommon
    Expected: 产出品质受材料品质正向影响
    Evidence: .sisyphus/evidence/task-18-quality-inherit.log
  ```

  **Commit**: YES | Message: `feat(crafting): 添加炼丹炼器制作系统CraftingService` | Files: [scripts/services/crafting_service.gd]

- [x] 19. 背包面板UI（完整实现替换占位）

  **What to do**:
  1. 修改 `scripts/ui/ui_root.gd` 中的 `_inventory_panel`（当前占位文本"背包功能正在开发中"）：
  2. 背包布局：
     - 左侧：物品列表（VBoxContainer + 品质颜色标记：common=白, uncommon=绿, rare=蓝, epic=紫, legendary=橙, mythic=红）
     - 右侧：物品详情面板（名称/描述/属性/词条/装备槽位）
     - 底部：操作按钮（装备/使用/丢弃/参悟-仅功法）
  3. 数据绑定：
     - 从 InventoryService.get_inventory(RunState.player_id) 获取物品列表
     - 从 InventoryService.get_equipped_stats 获取装备加成总览
     - 操作通过信号 → GameRoot → SimulationRunner → InventoryService
  4. 品质颜色方案（修改modulate）：
     - common: Color(0.8, 0.8, 0.8), uncommon: Color(0.3, 0.9, 0.3), rare: Color(0.3, 0.5, 1.0)
     - epic: Color(0.7, 0.3, 0.9), legendary: Color(1.0, 0.6, 0.1), mythic: Color(1.0, 0.2, 0.2)
  5. 实时刷新：监听 EventLog.entry_added，当事件类型为 ITEM_* 时刷新面板

  **Must NOT do**:
  - 不直接调用 InventoryService 的写操作（通过 GameRoot/SimulationRunner 中转）
  - 不修改 ui_root.gd 的其他面板

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - Reason: UI面板需要品质颜色、布局、交互
  - Skills: [`godot4-feature-dev`, `frontend-ui-ux`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 5 | Blocks: [] | Blocked By: [7,15]

  **References**:
  - Existing: `scripts/ui/ui_root.gd` - _inventory_panel 占位区域，需替换
  - Pattern: `scripts/ui/ui_root.gd:_build_world_characters_panel` - 现有面板构建模式
  - API/Type: `autoload/inventory_service.gd` - 数据查询接口
  - API/Type: `scripts/core/event_contracts.gd` - ITEM_* 事件用于刷新

  **Acceptance Criteria**:
  - [ ] 背包面板显示物品列表+品质颜色
  - [ ] 点击物品显示详情（属性/词条）
  - [ ] 装备按钮正确穿戴物品
  - [ ] 使用消耗品按钮正确消耗

  **QA Scenarios**:
  ```
  Scenario: 背包显示
    Tool: godot_run_project + take_screenshot
    Steps: 启动游戏 → 加载有物品的存档 → 切到背包面板 → 截图
    Expected: 物品列表可见，品质颜色正确，0 报错
    Evidence: .sisyphus/evidence/task-19-inventory-ui.png

  Scenario: 装备交互
    Tool: godot_run_project + simulate_input
    Steps: 点击物品 → 点击装备按钮 → 检查装备槽更新
    Expected: 装备槽显示新装备，旧装备自动卸下
    Evidence: .sisyphus/evidence/task-19-equip-interact.png
  ```

  **Commit**: YES | Message: `feat(ui): 实现背包面板UI含品质颜色与装备交互` | Files: [scripts/ui/ui_root.gd]

- [x] 20. 功法面板UI

  **What to do**:
  1. 在 `scripts/ui/ui_root.gd` 新增 `_technique_panel`（TabContainer 新标签页）：
  2. 布局：
     - 左侧：已学功法列表（品质颜色+门派标记+熟练度进度条）
     - 右侧：功法详情（效果描述/词条列表/学习条件/参悟按钮）
     - 技能槽位可视化（martial_1/spirit_1/ultimate/movement/passive_1/passive_2 六个槽位）
  3. 参悟界面：
     - 选择功法 → 显示词条列表（已解锁=高亮，未解锁=灰色）
     - 点击词条 → 参悟按钮（消耗灵石，显示预览品质范围）
     - 参悟后词条品质变化动画
  4. 门派独占标记：sect_exclusive_id非空时显示门派名称标签

  **Must NOT do**:
  - 不直接调用 TechniqueService 的写操作

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - Reason: 功法面板含技能槽位可视化、词条参悟交互
  - Skills: [`godot4-feature-dev`, `frontend-ui-ux`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 5 | Blocks: [] | Blocked By: [8,16]

  **References**:
  - Existing: `scripts/ui/ui_root.gd` - TabContainer 结构，新增标签页
  - Pattern: `scripts/ui/ui_root.gd:_build_favor_panel` - 现有标签页构建模式
  - API/Type: `scripts/services/technique_service.gd` - 功法查询/参悟接口

  **Acceptance Criteria**:
  - [ ] 功法面板显示已学功法列表+品质颜色+门派标记
  - [ ] 点击功法显示详情和词条
  - [ ] 参悟按钮消耗灵石并更新词条

  **QA Scenarios**:
  ```
  Scenario: 功法面板显示
    Tool: godot_run_project + take_screenshot
    Steps: 加载有功法的存档 → 切到功法面板 → 截图
    Expected: 功法列表可见，门派独占标记可见，0 报错
    Evidence: .sisyphus/evidence/task-20-technique-ui.png

  Scenario: 参悟交互
    Tool: godot_run_project + simulate_input
    Steps: 选择功法 → 点击词条 → 点击参悟 → 检查灵石减少和词条更新
    Expected: 参悟成功/失败消息显示，词条品质变化
    Evidence: .sisyphus/evidence/task-20-meditate-interact.log
  ```

  **Commit**: YES | Message: `feat(ui): 实现功法面板UI含词条参悟与门派标记` | Files: [scripts/ui/ui_root.gd]

- [x] 21. 战斗UI面板

  **What to do**:
  1. 在 `scripts/ui/ui_root.gd` 新增战斗弹出面板（当 RunState.sub_phase == "combat" 时显示）：
  2. 布局：
     - 顶部：双方状态条（名称/HP条/状态效果图标）
     - 中部：战斗日志（逐回合滚动文字）
     - 底部：行动选择区（可用功法按钮列表 + 使用物品按钮 + 逃跑按钮）
  3. 交互流程：
     - 每回合开始 → 显示可选项（从 TechniqueService.get_technique_combat_skills + InventoryService 消耗品列表）
     - 玩家选择行动 → 发出信号 → GameRoot → SimulationRunner → CombatManager 处理
     - 回合结算 → 日志更新 + HP条更新 → 下一回合
     - 战斗结束 → 显示结果（胜利/失败 + 掉落列表）→ 关闭面板
  4. HP条颜色：>60%绿色，30-60%黄色，<30%红色

  **Must NOT do**:
  - 不在UI中计算伤害（全部由 CombatManager 处理）

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - Reason: 战斗UI需状态条、日志滚动、行动按钮布局
  - Skills: [`godot4-feature-dev`, `frontend-ui-ux`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 5 | Blocks: [] | Blocked By: [9,17]

  **References**:
  - Existing: `scripts/ui/ui_root.gd` - 现有UI结构
  - Pattern: `scripts/ui/ui_root.gd:_build_event_modal` - 弹出面板模式
  - API/Type: `scripts/combat/combat_manager.gd` - 战斗引擎
  - API/Type: `scripts/data/combat_result_data.gd` - 战斗结果
  - API/Type: `autoload/run_state.gd:sub_phase` - "combat" 状态

  **Acceptance Criteria**:
  - [ ] sub_phase="combat" 时战斗面板显示
  - [ ] HP条正确反映双方生命值
  - [ ] 行动按钮列表从功法/消耗品动态生成
  - [ ] 战斗结束显示结果并关闭

  **QA Scenarios**:
  ```
  Scenario: 战斗UI显示
    Tool: godot_run_project + take_screenshot
    Steps: 触发战斗 → 截图战斗面板
    Expected: 双方HP条可见，行动按钮可点击，0 报错
    Evidence: .sisyphus/evidence/task-21-combat-ui.png

  Scenario: 战斗回合推进
    Tool: godot_run_project + simulate_input
    Steps: 选择攻击功法 → 点击 → 等待结算 → 检查HP条更新和日志
    Expected: 日志增加回合记录，对方HP减少
    Evidence: .sisyphus/evidence/task-21-combat-turn.log
  ```

  **Commit**: YES | Message: `feat(ui): 实现战斗UI面板含HP条/行动选择/战斗日志` | Files: [scripts/ui/ui_root.gd]

- [x] 22. 世界地图增强UI

  **What to do**:
  1. 修改 `scripts/ui/ui_root.gd` 的现有地图面板：
  2. 增强内容：
     - 每个区域节点显示资源图标/数量（从 WorldDynamicsService.get_region_state 获取）
     - 区域边框颜色反映控制势力（从 controlling_faction_id 映射颜色）
     - 危险等级指示（文字/颜色：安全=绿/低危=黄/高危=红）
     - 区域内NPC数量和名称缩略
     - 点击区域 → 弹出详情（资源产出率/库存/势力/人口/危险等级）
  3. 区域间路径显示（基于 adjacent_region_ids）

  **Must NOT do**:
  - 不改变区域树的基本结构（基于 Tree 控件的现有实现）

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - Reason: 地图增强需颜色/图标/详情弹出
  - Skills: [`godot4-feature-dev`, `frontend-ui-ux`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 5 | Blocks: [] | Blocked By: [10,14]

  **References**:
  - Existing: `scripts/ui/ui_root.gd:_build_map_panel` - 现有地图面板
  - API/Type: `scripts/services/world_dynamics_service.gd:get_region_state` - 区域状态
  - API/Type: `autoload/location_service.gd:get_all_regions` - 区域列表

  **Acceptance Criteria**:
  - [ ] 区域节点显示资源数量和势力颜色
  - [ ] 点击区域弹出详情含资源/势力/危险度

  **QA Scenarios**:
  ```
  Scenario: 地图增强显示
    Tool: godot_run_project + take_screenshot
    Steps: 加载有领地变更的存档 → 切到地图面板 → 截图
    Expected: 区域有势力颜色，资源数量可见
    Evidence: .sisyphus/evidence/task-22-map-enhanced.png

  Scenario: 区域详情
    Tool: godot_run_project + simulate_input
    Steps: 点击区域节点 → 检查弹出详情
    Expected: 详情含产出率/库存/势力/危险等级
    Evidence: .sisyphus/evidence/task-22-region-detail.png
  ```

  **Commit**: YES | Message: `feat(ui): 增强世界地图UI含资源/势力/危险度显示` | Files: [scripts/ui/ui_root.gd]

- [x] 23. 交易/商店UI

  **What to do**:
  1. 在 `scripts/ui/ui_root.gd` 新增交易弹出面板：
  2. 布局：
     - 左侧：NPC商品列表（NPC所在区域的资源+门派特色物品）
     - 右侧：玩家背包（可出售物品）
     - 中间：价格显示（base_value × 阵营关系修正：友好=0.8折，中立=1.0，敌对=1.5倍）
     - 底部：买入/卖出按钮 + 灵石余额
  3. 交易逻辑：
     - 买入：灵石减少 → InventoryService.add_item
     - 卖出：InventoryService.remove_item → 灵石增加（售价=base_value×0.5×阵营修正）
  4. 通过 GameRoot 中转调用 InventoryService

  **Must NOT do**:
  - 不创建独立交易服务（逻辑简单，直接在SimulationRunner中处理）

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - Reason: 交易面板需双栏布局、价格计算、阵营修正
  - Skills: [`godot4-feature-dev`, `frontend-ui-ux`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 5 | Blocks: [] | Blocked By: [7,15]

  **References**:
  - Existing: `scripts/ui/ui_root.gd` - 弹出面板模式
  - API/Type: `autoload/inventory_service.gd` - 物品增删
  - API/Type: `scripts/npc/relationship_network.gd` - favor 修正价格

  **Acceptance Criteria**:
  - [ ] 交易面板显示NPC商品+玩家背包
  - [ ] 买入扣除灵石+增加物品
  - [ ] 卖出增加灵石+移除物品
  - [ ] 阵营关系影响价格

  **QA Scenarios**:
  ```
  Scenario: 交易买入
    Tool: godot_run_project + simulate_input
    Steps: 打开交易面板 → 选择物品 → 点击买入 → 检查灵石减少+背包增加
    Expected: 灵石减少正确数额，物品在背包中
    Evidence: .sisyphus/evidence/task-23-trade-buy.log

  Scenario: 阵营价格修正
    Tool: godot_run_script
    Steps: 计算友好阵营价格 → 计算敌对阵营价格 → 比较
    Expected: 友好价格 < 中立 < 敌对
    Evidence: .sisyphus/evidence/task-23-faction-price.log
  ```

  **Commit**: YES | Message: `feat(ui): 实现交易/商店UI含阵营价格修正` | Files: [scripts/ui/ui_root.gd]

- [x] 24. 炼丹炼器制作UI

  **What to do**:
  1. 在 `scripts/ui/ui_root.gd` 新增制作弹出面板：
  2. 布局：
     - 左侧：可用配方列表（按类型分组：炼丹/炼器）
     - 右侧：配方详情（所需材料+当前库存+产出预览+成功率）
     - 底部：制作按钮 + 材料品质选择（如果有多种品质的同材料）
  3. 交互：
     - 选择配方 → 显示材料需求（红色=不足，绿色=充足）
     - 点击制作 → CraftingService.craft_item → 显示结果（成功/失败+产出品质）

  **Must NOT do**:
  - 不在UI中计算成功率（由 CraftingService 返回）

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - Reason: 制作面板需配方选择、材料状态、制作结果反馈
  - Skills: [`godot4-feature-dev`, `frontend-ui-ux`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: YES | Wave 5 | Blocks: [] | Blocked By: [18]

  **References**:
  - Existing: `scripts/ui/ui_root.gd` - 弹出面板模式
  - API/Type: `scripts/services/crafting_service.gd` - 制作接口
  - API/Type: `autoload/inventory_service.gd` - 材料库存查询

  **Acceptance Criteria**:
  - [ ] 配方列表按类型分组显示
  - [ ] 材料不足时显示红色标记
  - [ ] 制作成功/失败有结果反馈

  **QA Scenarios**:
  ```
  Scenario: 制作界面
    Tool: godot_run_project + take_screenshot
    Steps: 打开制作面板 → 选择配方 → 截图
    Expected: 配方详情可见，材料状态有颜色区分
    Evidence: .sisyphus/evidence/task-24-crafting-ui.png

  Scenario: 制作交互
    Tool: godot_run_project + simulate_input
    Steps: 材料充足时 → 点击制作 → 检查结果
    Expected: 成功/失败消息，物品变化
    Evidence: .sisyphus/evidence/task-24-craft-interact.log
  ```

  **Commit**: YES | Message: `feat(ui): 实现炼丹炼器制作UI含配方选择与材料状态` | Files: [scripts/ui/ui_root.gd]

- [x] 25. 存档迁移 v1→v2 + Snapshot扩展

  **What to do**:
  1. 修改 `scripts/sim/simulation_runner.gd` 的 `get_snapshot()`：
     - 增加 `inventory_data: Dictionary`（从 InventoryService.save_state）
     - 增加 `technique_data: Dictionary`（从 TechniqueService.save_state）
     - 增加 `world_dynamics_data: Dictionary`（从 WorldDynamicsService.save_state）
     - 增加 `crafting_data: Dictionary`（从 CraftingService.save_state）
     - 增加 `rng_state: Dictionary`（从 RngChannels.save_state）
     - 升级 SNAPSHOT_VERSION 从当前值到 +1
  2. 修改 `load_snapshot()`：
     - 加载新字段并传递给对应服务的 load_state
     - 旧版存档（缺新字段）→ 使用默认值初始化新系统
  3. 修改 `scripts/data/save_migration.gd`：
     - 新增 v1→v2 迁移函数：
       - 为每个 runtime_character 添加 inventory/equipment/learned_techniques/technique_slots/combat_stats 默认值
       - 为每个 region 添加 resource_stockpiles/production_rates 默认值
       - 初始化 rng_state 从旧 seed 字段派生
     - 迁移测试：加载v1存档 → 迁移 → 推进10tick → 无崩溃
  4. 更新 SaveService 中的 CURRENT_VERSION

  **Must NOT do**:
  - 不破坏v1存档的加载能力（迁移必须向后兼容）
  - 不删除现有 snapshot 字段

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 存档迁移是高风险操作，需严格验证
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: NO | Wave 6 | Blocks: [26] | Blocked By: [ALL above]

  **References**:
  - Existing: `scripts/sim/simulation_runner.gd:get_snapshot/load_snapshot` - 现有快照格式和校验逻辑
  - Existing: `scripts/data/save_migration.gd` - 现有迁移框架
  - Existing: `autoload/save_service.gd` - 存档服务
  - Pattern: 所有新增服务的 `save_state/load_state` 方法

  **Acceptance Criteria**:
  - [ ] v1存档可迁移到v2并正常加载
  - [ ] 迁移后推进10tick无崩溃
  - [ ] v2存档的 snapshot 包含所有新字段
  - [ ] v2→v2 加载无需迁移（零差异）

  **QA Scenarios**:
  ```
  Scenario: 存档迁移回归
    Tool: godot_run_script
    Steps: 创建v1格式snapshot → 执行迁移 → 检查新字段存在且非null → 推进10tick
    Expected: 迁移成功，0 崩溃，10tick后状态正常
    Evidence: .sisyphus/evidence/task-25-migration.log

  Scenario: v2存档往返
    Tool: godot_run_script
    Steps: 创建v2完整snapshot → get_snapshot → load_snapshot → get_snapshot → 比较两次输出
    Expected: 完全一致，0 差异
    Evidence: .sisyphus/evidence/task-25-save-roundtrip.log
  ```

  **Commit**: YES | Message: `feat(save): 存档迁移v1→v2含背包/功法/世界动态/战斗/RNG状态` | Files: [scripts/sim/simulation_runner.gd, scripts/data/save_migration.gd, autoload/save_service.gd]

- [x] 26. 集成验证（完整流程测试）

  **What to do**:
  1. 编写完整流程集成测试脚本 `scripts/dev/integration_test.gd`：
     - 新游戏 → 世界生成（含物品/功法/动态区域）→ 验证生成结果
     - 玩家拾取物品 → 装备 → 属性变化
     - 玩家学习功法 → 参悟词条 → 装备功法
     - 玩家进入战斗 → 选择行动 → 胜利获得掉落
     - 玩家炼丹/炼器 → 消耗材料 → 获得产出
     - 玩家与NPC交易 → 买入/卖出
     - NPC自主采集/学习/战斗/争夺领地
     - 区域资源产出/消耗循环
     - 保存 → 加载 → 推进 → 验证状态一致
     - 经济1000tick稳定性
  2. 所有验证为自动化断言，输出 pass/fail 结果
  3. 修复集成测试发现的问题

  **Must NOT do**:
  - 不手动测试（全自动化）

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 集成测试需理解所有系统交互
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-debugging`]

  **Parallelization**: Can Parallel: NO | Wave 6 | Blocks: [] | Blocked By: [25]

  **References**:
  - Existing: `scripts/dev/load_resources_smoke.gd` - 现有冒烟测试脚本模式
  - ALL services: InventoryService, TechniqueService, CombatManager, WorldDynamicsService, CraftingService
  - ALL data: WorldItemData, WorldTechniqueData, WorldCraftingRecipeData, WorldLootTableData

  **Acceptance Criteria**:
  - [ ] 集成测试脚本所有断言 pass
  - [ ] 1000tick经济稳定（货币增长<5%，stockpile非负）
  - [ ] 战斗确定性（同seed结果一致）

  **QA Scenarios**:
  ```
  Scenario: 完整流程集成
    Tool: godot_run_script
    Steps: 运行 integration_test.gd（timeout=120s）
    Expected: 所有断言pass，0 fail，0 error
    Evidence: .sisyphus/evidence/task-26-integration.log

  Scenario: 经济稳定性回归
    Tool: godot_run_script
    Steps: 1000tick仿真 → 统计总货币/关键材料库存
    Expected: 货币增长<5%，0个区域stockpile为负
    Evidence: .sisyphus/evidence/task-26-economy.log
  ```

  **Commit**: YES | Message: `test: 添加完整流程集成测试与经济稳定性验证` | Files: [scripts/dev/integration_test.gd]

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.
- [x] F1. Plan Compliance Audit — oracle
- [x] F2. Code Quality Review — unspecified-high
- [x] F3. Real Manual QA — unspecified-high (+ godot_run_project if UI)
- [x] F4. Scope Fidelity Check — deep

## Commit Strategy
- Wave1完成后: `feat(data): 添加物品/功法/制作/战斗数据模型与资源模板`
- Wave2完成后: `feat(services): 添加背包/功法/战斗/世界动态核心服务`
- Wave3完成后: `feat(world): 扩展世界生成与NPC行为集成`
- Wave4完成后: `feat(player): 集成玩家背包/功法/战斗/制作系统`
- Wave5完成后: `feat(ui): 实现背包/功法/战斗/地图/交易/制作UI面板`
- Wave6完成后: `feat(save): 存档迁移v1→v2与集成验证`

## Success Criteria
1. 固定seed世界生成产出一致的物品/功法/区域状态（确定性验证）
2. 物品品质分布符合配置权重（1000件采样统计）
3. 门派独占功法门禁正确阻断/放行
4. 文字回合战斗同seed 20次结果逐行一致
5. 1000tick仿真总货币增长<5%，关键材料库存非负
6. 领地变更后次tick资源产出按新归属倍率变化
7. 存档v1迁移到v2后推进10tick无崩溃
8. 所有UI面板可正常交互，无空引用崩溃

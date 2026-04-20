# 凡人玩法与 UI 全面升级

## TL;DR
> **Summary**: 全面重构"凡人"模式——新增角色创建流程、程序化世界生成、小时制时间系统、NPC行为库+关系网+记忆系统、主玩法UI重布局、存档版本化迁移，使凡人玩法从演示级变为可玩级。
> **Deliverables**: 模式选择页、角色创建页、世界初始化页、主玩法UI（左侧NPC面板+右侧信息面板）、4档时间速度控制、NPC行为库+关系网+记忆、程序化世界生成、存档V2协议与迁移
> **Effort**: XL
> **Parallel**: YES - 5 waves
> **Critical Path**: T1/T2/T3/T4 → T5/T6/T7/T8 → T9/T10/T11/T12 → T13-T16 → T17-T19 → F1-F4

## Context
### Original Request
用户要求全面重新设计凡人模式的UI流程和玩法：
- 开始游戏 → 选择玩法（凡人/神明） → 凡人设定页面（名字、道德偏好、出生等，参考太吾绘卷/鬼谷八荒/修仙模拟器） → 开始游戏 → 初始化页面（创建NPC、关系、世界地图、资源、怪物、功法） → 主玩法界面
- 时间按小时计算，4档速度（0.5时/2秒、1时/2秒、1天/2秒、1月/2秒）
- NPC大行为库+模拟真人决策
- 每次新游戏世界和NPC全新生成
- UI大小合适、不重叠不遮挡
- 保存/加载游戏功能
- 凡人玩法优先，高可玩性

### Interview Summary
- 当前代码库：UIRoot全代码构建5面板，SimulationRunner约2175行+7事件模板+4需NPC AI，TimeService以分钟为最小advance单位但advance_day是主入口，HumanEarlyLoop策略化行动选择，HumanOpeningBuilder硬编码预设，SaveService有slot+JSON+校验+temp文件模式
- 技术决策：时间从天改为小时、角色创建插在menu与bootstrap之间、NPC从静态模板升级为行为库+关系网+记忆、世界从catalog sample改为程序化生成、UI从全代码迁移为scene+script混合
- 参考游戏：太吾绘卷（连续立场轴、出生地选择、印象系统）、鬼谷八荒（7类关系、-300~+300好感、NPC主动社交）、修仙模拟器（风水系统、弟子分配、实时+加速）

### Metis Review (gaps addressed)
- **性能守卫**：小时制导致tick数量指数增加，必须解耦"推进粒度"与"决策粒度"，设定每tick性能预算
- **数据版本守卫**：存档需schema version + migration，禁止无版本字段漂移
- **范围守卫**：神明模式本期仅保留入口占位，Must NOT有内容扩展
- **验证守卫**：每阶段必须有agent可执行的QA，不接受主观目测验收
- **MVP硬边界**：首版要求"可创建角色→生成世界→跑满3年不崩→可存读"，不追求"真人级社交智能"
- **世界可复现**：同seed必须可复现世界，用于调试和平衡性调整
- **初始化可观测**：分阶段任务+进度反馈+失败恢复+种子可复现
- **UI分层替换**：不一次性替换全部面板，先做流程壳层，再逐步替换子面板

## Work Objectives
### Core Objective
将凡人模式从演示级（固定预设角色、日推进、8个行动选项）升级为可玩级（角色创建→程序化世界→小时制推进→NPC行为库+关系→可存读），同时维持代码架构整洁和性能。

### Deliverables
1. 流程状态机：menu → mode_select → char_creation → world_init → main_play 五阶段
2. 玩法选择页面（凡人/神明入口）
3. 角色创建页面（名字、道德偏好、出生地、难度等）
4. 世界初始化进度页面（种子显示、NPC/关系/资源生成进度条）
5. 小时制TimeService + 4档速度控制
6. WorldGenerator（程序化世界：NPC、关系、地图、资源、怪物、功法）
7. NpcBehaviorLibrary（行为库：行动ID→标签→影响→条件→权重）
8. RelationshipNetwork（7类关系、-300~+300好感、NPC主动社交）
9. NpcMemorySystem（事件摘要、衰减规则、容量限制）
10. NpcDecisionEngine（需求+关系+记忆驱动决策，解耦于时间推进）
11. 主玩法UI布局（左侧：NPC头像+简况+详情按钮+窗口按钮；右侧：地图/日志/世界角色信息切换）
12. 存档V2协议（save_version=2、migration pipeline）
13. UI不重叠验证脚本

### Definition of Done (verifiable conditions with commands)
- [ ] `godot4-runtime_run_project` → 自动化输入可走通"菜单→选凡人→创建角色→世界初始化→主玩法界面"，断言 `RunState.phase == "main_play"`
- [ ] `godot4-runtime_run_script` 遍历所有可见Control节点，统计矩形重叠率，断言无Critical级重叠
- [ ] 4档时间各运行10秒（5个tick），断言推进量分别接近 2.5h / 5h / 120h / 3600h（容差±30%）；即 tier1=0.5h/tick, tier2=1h/tick, tier3=24h/tick(1天), tier4=720h/tick(30天=1月)
- [ ] 两局不同seed游戏，NPC主键集合差异率 > 50%，且无固定预制ID
- [ ] 触发NPC社交行为后，favor值在[-300, 300]内并按规则变化
- [ ] 存档→读档后关键数据（时间、角色属性、关系边数量、地图资源点数）完全一致
- [ ] 加载损坏JSON存档，断言返回明确错误码、不崩溃不卡死
- [ ] 目标规模(200 NPC)下模拟30秒，无fatal/error输出，tick耗时p95 < 50ms

### Must Have
- 五阶段流程状态机完整可走通
- 角色创建至少支持：自定义名字、道德偏好（连续轴）、出生地选择、开局类型选择
- 小时制时间推进，4档可切换速度
- 程序化世界生成（seed可复现）
- NPC行为库至少40个行为定义
- 关系系统支持至少5种关系类型、好感度-300~+300
- NPC记忆系统（事件摘要、衰减、容量上限）
- 主玩法UI左侧NPC信息+右侧信息切换
- 存档V2协议含版本迁移
- UI无Critical级重叠

### Must NOT Have (guardrails)
- ❌ 神明模式内容扩展（仅保留"施工中"入口占位）
- ❌ 战斗系统
- ❌ 美术资源制作
- ❌ 音效/音乐
- ❌ 多语言/i18n
- ❌ 一次性全量替换UI面板（必须分层替换）
- ❌ 主观"真人级"NPC行为目标（可量化验收标准代替）
- ❌ 无seed可复现的世界生成
- ❌ 无版本字段的存档格式漂移
- ❌ 每小时全量AI重算（必须解耦推进粒度和决策粒度）

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: tests-after + Godot runtime QA (no existing test framework found)
- QA policy: Every task has agent-executed scenarios (happy path + failure path)
- Evidence: .sisyphus/evidence/task-{N}-{slug}.{ext}
- Tools: godot4-runtime_run_project, godot4-runtime_simulate_input, godot4-runtime_get_ui_elements, godot4-runtime_run_script, godot4-runtime_validate, godot4-runtime_get_debug_output

## Execution Strategy
### Parallel Execution Waves
> Target: 4-5 tasks per wave. Extract shared dependencies as Wave-1.

**Wave 1: Foundation Layer** (4 tasks, all parallel, no dependencies)
- T1 [deep]: RunState + GameRoot 流程状态机重构
- T2 [deep]: TimeService 小时制核心 + 速度档位
- T3 [deep]: 统一数据模型定义
- T4 [quick]: SaveService 版本协议 + 迁移框架

**Wave 2: Core Systems** (4 tasks, parallel, depends on T1+T3)
- T5 [deep]: WorldGenerator 程序化世界生成
- T6 [deep]: NpcBehaviorLibrary 行为库
- T7 [deep]: RelationshipNetwork 关系网系统
- T8 [visual-engineering]: 模式选择 + 角色创建 UI 场景

**Wave 3: Decision & Integration** (4 tasks, depends on T5+T6+T7+T2+T4)
- T9 [deep]: NpcMemorySystem 记忆系统
- T10 [deep]: NpcDecisionEngine 决策引擎
- T11 [deep]: SimulationRunner 集成重构
- T12 [visual-engineering]: 世界初始化 + 时间速度控制 UI

**Wave 4: Main Gameplay UI + Save** (4 tasks, depends on T11+T8+T12)
- T13 [visual-engineering]: 主玩法 UI 布局重设计
- T14 [visual-engineering]: 日志 + 地图面板重构
- T15 [deep]: Save/Load 游戏流程重构
- T16 [visual-engineering]: CharacterPanel NPC信息重构

**Wave 5: Validation & Stability** (3 tasks, depends on T13+T14+T15+T16)
- T17 [deep]: UI 碰撞检测 + 布局验证
- T18 [deep]: 性能预算验证 + 调优
- T19 [deep]: 全流程端到端自动化验收

**F-Wave: Final Verification** (4 tasks, parallel, depends on all)
- F1. Plan Compliance Audit — oracle
- F2. Code Quality Review — unspecified-high
- F3. Real Manual QA — unspecified-high (+ playwright if UI)
- F4. Scope Fidelity Check — deep

### Dependency Matrix

| Task | Blocked By | Blocks |
|------|-----------|--------|
| T1 | — | T5, T6, T7, T8 |
| T2 | — | T11, T12 |
| T3 | — | T5, T6, T7, T8 |
| T4 | — | T15 |
| T5 | T1, T3 | T11 |
| T6 | T3 | T10 |
| T7 | T3 | T10 |
| T8 | T1 | T12 |
| T9 | T3, T7 | T10 |
| T10 | T6, T7, T9 | T11 |
| T11 | T2, T5, T10 | T13, T14, T15, T16 |
| T12 | T2, T8 | T13 |
| T13 | T11, T12 | T17 |
| T14 | T11 | T17 |
| T15 | T4, T11 | T19 |
| T16 | T11 | T17 |
| T17 | T13, T14, T16 | T19 |
| T18 | T11 | T19 |
| T19 | T17, T18, T15 | — |

### Agent Dispatch Summary
| Wave | Tasks | Categories |
|------|-------|-----------|
| 1 | 4 | deep x3, quick x1 |
| 2 | 4 | deep x3, visual-engineering x1 |
| 3 | 4 | deep x3, visual-engineering x1 |
| 4 | 4 | deep x1, visual-engineering x3 |
| 5 | 3 | deep x3 |
| F | 4 | oracle x1, unspecified-high x2, deep x1 |

## TODOs

- [x] T1. RunState + GameRoot 流程状态机重构

  **What to do**:
  1. 在 `autoload/run_state.gd` 中新增流程阶段常量：`&"mode_select"`, `&"char_creation"`, `&"world_init"`, `&"main_play"`（保留现有 `&"menu"`, `&"running"`, `&"ready"`）
  2. 新增 `sub_phase: StringName` 字段和 `sub_phase_changed` 信号，用于 char_creation 内部子步骤状态（如"basic_info"/"moral"/"birth"/"confirm"）
  3. 新增 `creation_params: Dictionary` 字段，存储角色创建参数（由 char_creation UI 填入）
  4. 新增 `world_seed: int` 字段，存储世界种子（由 world_init 用）
  5. 在 `scripts/game_root.gd` 中重构流程：
     - `_on_new_game_requested(mode)` 不再直接调 `bootstrap()`，改为 `RunState.set_phase(&"mode_select")`
     - 新增 `_on_mode_selected(mode: StringName)` 信号处理器：凡人→`set_phase(&"char_creation")`，神明→显示"施工中"弹窗
     - 新增 `_on_character_created(params: Dictionary)` 信号处理器：存入 `RunState.creation_params`，`set_phase(&"world_init")`
     - 新增 `_on_world_initialized()` 信号处理器：`set_phase(&"main_play")`，启动 auto_advance_timer（此时基于小时制）
     - 保留 `_on_continue_requested()` 逻辑不变（继续游戏直接进入 main_play）
  6. 在 `ui_root.gd` 中新增信号：`mode_selected(mode: StringName)`, `character_created(params: Dictionary)`, `world_initialized()`
  7. 用 `godot4-runtime_validate` 验证修改后的脚本无语法错误

  **Must NOT do**:
  - ❌ 不修改 SimulationRunner.bootstrap() 的内部逻辑（T11 处理）
  - ❌ 不删除现有 `running`/`ready` phase（向下兼容继续游戏流程）
  - ❌ 不创建新的 .tscn 场景文件（T8/T12/T13 处理UI场景）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 核心流程状态机重构，需要理解现有流程和多文件联动
  - Skills: [`godot4-feature-dev`] — Godot 场景+脚本架构
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: T5, T6, T7, T8 | Blocked By: —

  **References**:
  - Pattern: `autoload/run_state.gd` — 当前 phase/mode 结构（21行）
  - Pattern: `scripts/game_root.gd` — 当前流程入口（126行），特别是 `_on_new_game_requested()` 和 `_on_continue_requested()`
  - Pattern: `scripts/ui/ui_root.gd:1-80` — 信号定义和 `_ready()` 连接方式
  - API: `RunState.set_phase()`, `RunState.set_mode()` — 现有API

  **Acceptance Criteria** (agent-executable only):
  - [ ] `godot4-runtime_validate` 对 `run_state.gd` 和 `game_root.gd` 无错误
  - [ ] `godot4-runtime_run_script` 验证新 phase 常量存在且 `RunState.phase` 可被设为 `mode_select`, `char_creation`, `world_init`, `main_play`
  - [ ] `godot4-runtime_run_script` 验证 `RunState.creation_params` 和 `RunState.world_seed` 字段可读写

  **QA Scenarios**:
  ```
  Scenario: 新阶段常量设置正常
    Tool: godot4-runtime_run_script
    Steps:
      1. 在运行的游戏中执行脚本，设置 RunState.phase = "mode_select"
      2. 断言 phase 等于 "mode_select"
      3. 逐一测试 "char_creation", "world_init", "main_play"
      4. 断言 sub_phase_changed 信号存在
    Expected: 所有阶段可设置，信号正常
    Evidence: .sisyphus/evidence/task-1-runstate-phases.txt

  Scenario: 旧阶段向下兼容
    Tool: godot4-runtime_run_script
    Steps:
      1. 设置 RunState.phase = "running"
      2. 断言 phase 等于 "running"
      3. 设置 mode = "human"，断言正常
    Expected: 旧阶段不受影响
    Evidence: .sisyphus/evidence/task-1-backward-compat.txt
  ```

  **Commit**: YES | Message: `feat(flow): 扩展流程状态机新增五阶段` | Files: `autoload/run_state.gd`, `scripts/game_root.gd`, `scripts/ui/ui_root.gd`

- [x] T2. TimeService 小时制核心 + 速度档位

  **What to do**:
  1. 在 `autoload/time_service.gd` 中新增小时制核心：
     - 新增 `signal hour_advanced(total_hours: float)`
     - 新增 `signal month_changed(month: int)`
     - 新增 `var speed_tier: int = 2` 字段（1=0.5时/2秒, 2=1时/2秒, 3=1天/2秒, 4=1月/2秒）
     - 新增 `var hours_per_tick: float` 计算属性，根据 speed_tier 返回对应值：tier1=0.5, tier2=1.0, tier3=24.0(1天), tier4=720.0(30天=1月)
     - 新增 `var total_hours: float` 字段（替代 `total_minutes` 作为主时间累积器）
     - 保留 `day`, `minute_of_day` 字段向下兼容（从 total_hours 派生）
     - 新增 `func advance_hours(hours: float)` 方法
     - 修改 `advance_minutes()` 内部改为通过 hours 换算
     - 修改 `get_snapshot()` 包含 `total_hours`, `speed_tier`, `hours_per_tick`
  2. 在 `time_service.gd` 中新增速度控制：
     - 新增 `func set_speed_tier(tier: int)` 方法（1-4，超出范围clamp）
     - 新增 `signal speed_tier_changed(tier: int)` 信号
     - 新增 `func get_speed_tier_name() -> StringName` 方法（返回 `&"half_hour"`, `&"one_hour"`, `&"one_day"`, `&"one_month"`）
     - 新增 `func get_clock_text_detailed() -> String` 方法（返回"第X天 HH:MM"格式，已有但确保使用 total_hours）
  3. 保持向下兼容：`advance_day()` 和 `advance_days()` 仍然可用，内部调用 hours
  4. 确保月的概念：设定每30天为1个月，`month = (day - 1) / 30 + 1`

  **Must NOT do**:
  - ❌ 不修改 GameRoot 的 timer 逻辑（T11会重写）
  - ❌ 不修改 SimulationRunner 的 advance 逻辑（T11处理）
  - ❌ 不删除 `advance_day()`/`advance_days()`（向下兼容）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 核心时间系统重构，需要数学精度和向下兼容
  - Skills: [`godot4-feature-dev`] — Godot 脚本开发
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: T11, T12 | Blocked By: —

  **References**:
  - Pattern: `autoload/time_service.gd` — 当前时间服务（75行），`advance_minutes()`, `advance_day()`, `get_snapshot()`, `MINUTES_PER_DAY`
  - Pattern: `scripts/game_root.gd:106-126` — auto_advance_timer 使用 `AUTO_ADVANCE_INTERVAL_SECONDS = 2.0`
  - API: `TimeService.get_total_minutes()`, `TimeService.get_clock_text()`, `TimeService.day`, `TimeService.minute_of_day`

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对 `time_service.gd` 无错误
  - [ ] `advance_hours(24.0)` 后 `day` 递增1，`total_hours` 增加24
  - [ ] `advance_day()` 仍然工作（向下兼容）
  - [ ] `set_speed_tier(1)` → `hours_per_tick == 0.5`; tier 2 → 1.0; tier 3 → 24.0; tier 4 → 720.0
  - [ ] 速度档位非1-4范围时自动clamp到有效范围

  **QA Scenarios**:
  ```
  Scenario: 小时制推进正确性
    Tool: godot4-runtime_run_script
    Steps:
      1. 重置时钟 TimeService.reset_clock()
      2. 调用 TimeService.advance_hours(5.5)
      3. 断言 total_hours ≈ 5.5, day == 1, minute_of_day ≈ 330 (5h30m = 330min)
      4. 再调用 TimeService.advance_hours(18.5)
      5. 断言 total_hours ≈ 24.0, day == 2, minute_of_day == 0 (跨日重置为0点)
    Expected: 小时精度时间推进正确
    Evidence: .sisyphus/evidence/task-2-hour-advance.txt

  Scenario: 速度档位设置
    Tool: godot4-runtime_run_script
    Steps:
      1. 调用 TimeService.set_speed_tier(1), 断言 hours_per_tick == 0.5
      2. 调用 TimeService.set_speed_tier(3), 断言 hours_per_tick == 24.0
      3. 调用 TimeService.set_speed_tier(0), 断言自动clamp到1
      4. 调用 TimeService.set_speed_tier(5), 断言自动clamp到4
    Expected: 速度档位计算正确，越界自动修正
    Evidence: .sisyphus/evidence/task-2-speed-tier.txt

  Scenario: 向下兼容advance_day
    Tool: godot4-runtime_run_script
    Steps:
      1. 重置时钟
      2. 调用 TimeService.advance_day()
      3. 断言 day == 2, total_hours ≈ 24.0
    Expected: 旧接口仍然工作
    Evidence: .sisyphus/evidence/task-2-backward-compat.txt
  ```

  **Commit**: YES | Message: `feat(time): 小时制时间核心+4档速度控制` | Files: `autoload/time_service.gd`

- [x] T3. 统一数据模型定义

  **What to do**:
  1. 创建 `scripts/data/character_creation_params.gd`（extends RefCounted）：
     - `var character_name: String = ""`
     - `var morality_value: float = 0.0`（-100 刚正 到 +100 唯我，参考太吾绘卷连续轴）
     - `var birth_region_id: StringName = &""`
     - `var opening_type: StringName = &"youth"`（youth/young_adult/adult）
     - `var difficulty: int = 1`（1-3）
     - `var custom_seed: int = -1`（-1表示自动生成）
     - `func to_dict() -> Dictionary` 和 `static func from_dict(data: Dictionary) -> CharacterCreationParams`
  2. 创建 `scripts/data/relationship_edge.gd`（extends RefCounted）：
     - `var source_id: StringName`
     - `var target_id: StringName`
     - `var relation_type: StringName`（如 &"family", &"friend", &"rival", &"mentor", &"disciple", &"ally", &"enemy"）
     - `var favor: int = 0`（-300 到 +300）
     - `var trust: int = 0`（-100 到 +100）
     - `var interaction_count: int = 0`
     - `func modify_favor(delta: int) -> void`（clamp到[-300, 300]）
     - `func modify_trust(delta: int) -> void`（clamp到[-100, 100]）
     - `func to_dict() -> Dictionary` 和 `static func from_dict(data: Dictionary) -> RelationshipEdge`
  3. 创建 `scripts/data/npc_memory_entry.gd`（extends RefCounted）：
     - `var event_id: StringName`
     - `var event_type: StringName`（如 &"social", &"conflict", &"trade", &"cultivation"）
     - `var timestamp_hours: float`
     - `var importance: int = 1`（1-10，影响衰减速度）
     - `var summary: String = ""`
     - `var related_ids: PackedStringArray = []`（相关角色ID）
     - `func get_age_hours(current_hours: float) -> float`（计算记忆年龄）
     - `func get_retention_score(current_hours: float) -> float`（importance / (1 + age_hours / 24.0)，衰减公式）
     - `func to_dict() -> Dictionary` 和 `static func from_dict(data: Dictionary) -> NpcMemoryEntry`
  4. 创建 `scripts/data/behavior_action.gd`（extends RefCounted）：
     - `var action_id: StringName`
     - `var label: String`
     - `var category: StringName`（如 &"survival", &"social", &"cultivation", &"exploration", &"conflict"）
     - `var pressure_deltas: Dictionary = {}`（branch → delta）
     - `var favor_deltas: Dictionary = {}`（relation_type → delta）
     - `var conditions: Dictionary = {}`（执行条件，如 minimum_realm, minimum_favor 等）
     - `var weight: float = 1.0`
     - `var description: String = ""`（行为描述文本）
     - `var cooldown_hours: float = 0.0`（行为冷却时间）
     - `func to_dict() -> Dictionary` 和 `static func from_dict(data: Dictionary) -> BehaviorAction`
  5. 创建 `scripts/data/world_seed_data.gd`（extends RefCounted）：
     - `var seed_value: int`
     - `var region_count: int = 7`
     - `var npc_count: int = 30`
     - `var resource_density: float = 0.5`
     - `var monster_density: float = 0.3`
     - `func to_dict() -> Dictionary` 和 `static func from_dict(data: Dictionary) -> WorldSeedData`
  6. 所有数据类必须包含 `SNAPSHOT_VERSION` 常量和 `get_snapshot() -> Dictionary` 方法

  **Must NOT do**:
  - ❌ 不修改现有 `SimulationRunner` 或 `HumanModeRuntime` 的数据结构
  - ❌ 不创建 Resource 文件（.tres），仅 GDScript 数据类
  - ❌ 不在此任务创建世界生成逻辑（T5处理）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 数据模型定义，影响所有后续系统
  - Skills: [`godot4-feature-dev`] — GDScript 数据类设计
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: T5, T6, T7, T8 | Blocked By: —

  **References**:
  - Pattern: `scripts/modes/human/human_early_loop.gd:9-112` — ACTION_DEFS 结构（行为定义的参考格式）
  - Pattern: `scripts/modes/human/human_opening_builder.gd:1-60` — OPENING_PRESETS（角色创建参数参考）
  - Pattern: `scripts/sim/simulation_runner.gd:14-37` — 需求常量和世界反馈状态（数据模型参考）
  - Pattern: `autoload/time_service.gd:68-75` — get_snapshot() 模式

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对所有5个新数据类文件无错误
  - [ ] 每个数据类可实例化、设值、to_dict/from_dict round-trip 一致
  - [ ] RelationshipEdge.modify_favor() 限制在 [-300, 300]
  - [ ] NpcMemoryEntry.get_retention_score() 随时间衰减

  **QA Scenarios**:
  ```
  Scenario: 数据类 round-trip 一致性
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 CharacterCreationParams 实例，设置各字段
      2. 调用 to_dict() → from_dict()，断言所有字段一致
      3. 对 RelationshipEdge, NpcMemoryEntry, BehaviorAction, WorldSeedData 重复
    Expected: 所有数据类序列化/反序列化正确
    Evidence: .sisyphus/evidence/task-3-datamodel-roundtrip.txt

  Scenario: 关系好感度边界
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 RelationshipEdge, favor = 0
      2. modify_favor(500), 断言 favor == 300
      3. modify_favor(-700), 断言 favor == -300
      4. 创建 RelationshipEdge, trust = 0
      5. modify_trust(150), 断言 trust == 100
    Expected: 好感度和信任度正确限制
    Evidence: .sisyphus/evidence/task-3-relationship-bounds.txt

  Scenario: 记忆衰减计算
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 NpcMemoryEntry, importance = 5, timestamp_hours = 0
      2. current_hours = 0, 断言 retention_score ≈ 5.0
      3. current_hours = 24, 断言 retention_score ≈ 2.5 (5/(1+1))
      4. current_hours = 240, 断言 retention_score < 1.0
    Expected: 记忆衰减公式计算正确
    Evidence: .sisyphus/evidence/task-3-memory-decay.txt
  ```

  **Commit**: YES | Message: `feat(data): 统一数据模型定义（角色创建/关系/记忆/行为/世界种子）` | Files: `scripts/data/character_creation_params.gd`, `scripts/data/relationship_edge.gd`, `scripts/data/npc_memory_entry.gd`, `scripts/data/behavior_action.gd`, `scripts/data/world_seed_data.gd`

- [x] T4. SaveService 版本协议 + 迁移框架

  **What to do**:
  1. 在 `autoload/save_service.gd` 中：
     - 更新 `SAVE_PROTOCOL_VERSION` 从 1 升到 2
     - 新增 `func migrate_save(data: Dictionary, from_version: int) -> Dictionary` 方法
     - 实现 `migrate_v1_to_v2(data: Dictionary) -> Dictionary` 方法（将旧版v1存档迁移到v2格式：保留现有字段 + 新增 `creation_params`, `world_seed_data`, `relationship_network`, `npc_memories` 空字典）
     - 新增 `func has_save_slot(slot_id: String = DEFAULT_SLOT_ID) -> bool` 方法（检查存档是否存在）
     - 新增 `func get_save_info(slot_id: String = DEFAULT_SLOT_ID) -> Dictionary` 方法（返回存档基本信息：版本号、时间戳、模式，不加载全部数据）
     - 修改 `_validate_payload()` 支持版本迁移：如果 `save_version` 低于 `SAVE_PROTOCOL_VERSION`，自动调用 `migrate_save()`
  2. 在 `scripts/data/save_migration.gd` 中创建迁移工具类：
     - `static func v1_to_v2(data: Dictionary) -> Dictionary`
     - 未来可扩展的迁移注册模式
  3. 保留向下兼容：v1 格式存档可自动迁移为v2

  **Must NOT do**:
  - ❌ 不删除 v1 存档格式的支持（必须可迁移）
  - ❌ 不修改 GameRoot 的 `_on_continue_requested()` 逻辑流程（T15处理）
  - ❌ 不在此任务处理新的数据结构迁移细节（T15处理）

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: 存档协议扩展，模式清晰，工作量适中
  - Skills: [`godot4-feature-dev`] — GDScript 文件操作
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: T15 | Blocked By: —

  **References**:
  - Pattern: `autoload/save_service.gd` — 完整的存档服务（263行），JSON序列化+校验+temp文件模式
  - Pattern: `autoload/save_service.gd:6-22` — 版本常量和错误码
  - Pattern: `autoload/save_service.gd:40-94` — save_slot() 写入流程
  - Pattern: `autoload/save_service.gd:96-142` — load_slot() 读取+校验流程
  - Pattern: `autoload/save_service.gd:153-211` — _validate_payload() 校验逻辑
  - Pattern: `scripts/game_root.gd:46-73` — _on_continue_requested() 存档加载流程

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对修改后的 `save_service.gd` 和新 `save_migration.gd` 无错误
  - [ ] `SAVE_PROTOCOL_VERSION == 2`
  - [ ] v1格式存档可自动迁移为v2（migrate_v1_to_v2 返回包含新字段的 Dictionary）
  - [ ] `has_save_slot()` 和 `get_save_info()` 方法可用

  **QA Scenarios**:
  ```
  Scenario: v1到v2自动迁移
    Tool: godot4-runtime_run_script
    Steps:
      1. 构造 v1 格式存档 Dictionary（save_version=1, 缺少 creation_params 等字段）
      2. 调用 SaveService.migrate_save(data, 1)
      3. 断言返回值包含 creation_params, world_seed_data, relationship_network, npc_memories 字段
      4. 断言原有的 seed, runtime_characters 等字段保留不变
    Expected: v1数据自动迁移为v2，新增字段用空字典填充
    Evidence: .sisyphus/evidence/task-4-v1-to-v2-migration.txt

  Scenario: 存档存在性检查
    Tool: godot4-runtime_run_script
    Steps:
      1. 调用 SaveService.has_save_slot("nonexistent"), 断言返回 false
      2. 保存一个存档到 "test_slot"
      3. 调用 SaveService.has_save_slot("test_slot"), 断言返回 true
      4. 调用 SaveService.get_save_info("test_slot"), 断言返回包含 version/timestamp/mode 的 Dictionary
    Expected: 存档存在性检查和信息读取正常
    Evidence: .sisyphus/evidence/task-4-has-save.txt

  Scenario: 损坏存档处理
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建一个格式错误的 JSON 文件到 user://saves/corrupt.json
      2. 调用 SaveService.load_slot("corrupt")
      3. 断言返回 ok=false 且 error 包含 JSON 解析错误描述
      4. 断言不崩溃不卡死
    Expected: 损坏存档优雅处理
    Evidence: .sisyphus/evidence/task-4-corrupt-save.txt
  ```

  **Commit**: YES | Message: `feat(save): 存档V2协议+迁移框架` | Files: `autoload/save_service.gd`, `scripts/data/save_migration.gd`

- [x] T5. WorldGenerator 程序化世界生成

  **What to do**:
  1. 创建 `scripts/world/world_generator.gd`（extends RefCounted, class_name WorldGenerator）：
     - `func generate(seed_data: WorldSeedData) -> Dictionary` — 主入口，返回包含 regions, characters, relationships, resources, monsters, cultivation_methods 的世界 Dictionary
     - `func generate_regions(seed_data: WorldSeedData) -> Array[Dictionary]` — 程序化生成区域（名称、地形、气候、资源分布）
     - `func generate_characters(seed_data: WorldSeedData, regions: Array[Dictionary]) -> Array[Dictionary]` — 程序化生成NPC（姓名、属性、出生地、职业）
     - `func generate_relationships(characters: Array[Dictionary], seed: int) -> Array[Dictionary]` — 程序化生成初始关系网
     - `func generate_resources(regions: Array[Dictionary], seed: int) -> Array[Dictionary]` — 资源点分布
     - `func generate_monsters(regions: Array[Dictionary], seed: int) -> Array[Dictionary]` — 怪物分布
     - `func generate_cultivation_methods(seed: int) -> Array[Dictionary]` — 功法生成
     - 内部使用 SeededRandom 确保同seed可复现
  2. NPC姓名生成：创建 `scripts/world/name_generator.gd`：
     - 姓氏池（百家姓前50）/ 名字池（君子名、修真名），使用 seed 伪随机选择
  3. 区域名称生成：使用修仙世界观命名规则（山脉、城市、秘境等）
  4. 确保同 seed 完全可复现（所有随机调用通过 SeededRandom）
  5. 初始NPC数量由 WorldSeedData.npc_count 控制（默认30）
  6. 关系网确保每个NPC至少有1-3条关系边
  7. 宗门/家族/散修等势力分布合理
  8. 保留对 `resources/world/world_data_catalog.tres` 的兼容（可作为 fallback）

  **Must NOT do**:
  - ❌ 不修改 SimulationRunner（T11集成）
  - ❌ 不硬编码NPC名称或属性（全部程序化生成）
  - ❌ 不在此任务创建UI（T12/T13处理）
  - ❌ 不使用 RandomNumberGenerator（必须用 SeededRandom 确保可复现）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 复杂的程序化生成系统
  - Skills: [`godot4-feature-dev`] — GDScript 数据生成
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: T11 | Blocked By: T1, T3

  **References**:
  - Pattern: `scripts/sim/seeded_random.gd` — SeededRandom 类
  - Pattern: `scripts/sim/simulation_runner.gd:74-78` — bootstrap() 和 reset_simulation() 流程
  - Pattern: `scripts/sim/simulation_runner.gd:80-97` — _build_runtime_characters() 用 catalog sample
  - Pattern: `scripts/resources/world_data_catalog.gd` — 世界数据目录结构
  - Pattern: `scripts/resources/world_region_data.gd`, `world_character_data.gd`, `world_family_data.gd`, `world_faction_data.gd` — 现有数据资源脚本
  - External: 太吾绘卷开放世界随机生成逻辑（区域+NPC+关系联动）

  **Acceptance Criteria**:
  - [ ] 同 seed 两次调用 generate() 结果完全一致
  - [ ] 不同 seed 两次调用 NPC 主键集合差异率 > 50%
  - [ ] 生成的世界无固定预制ID（如 mvp_village_heir）
  - [ ] 每个 NPC 至少 1 条关系边
  - [ ] 30个NPC生成耗时 < 100ms

  **QA Scenarios**:
  ```
  Scenario: 同seed可复现
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 WorldSeedData, seed=12345, npc_count=30
      2. 调用 WorldGenerator.generate(seed_data) 两次
      3. 比较两次结果的 characters 数组中所有 id 字段
      4. 断言两次结果完全一致
    Expected: 同seed完全可复现
    Evidence: .sisyphus/evidence/task-5-seed-reproducibility.txt

  Scenario: 不同seed差异率
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建两个不同seed的 WorldSeedData (seed=111, seed=222)
      2. 分别调用 WorldGenerator.generate()
      3. 比较两次 characters 的 id 集合
      4. 断言差异率 > 50%
    Expected: 不同seed生成完全不同的世界
    Evidence: .sisyphus/evidence/task-5-seed-diversity.txt

  Scenario: 关系网完整性
    Tool: godot4-runtime_run_script
    Steps:
      1. 生成世界 (npc_count=30)
      2. 遍历所有NPC，统计每个NPC的关系边数量
      3. 断言每个NPC至少 1 条关系边
      4. 断言所有关系边的 source_id/target_id 都在角色集合中
    Expected: 关系网连通完整
    Evidence: .sisyphus/evidence/task-5-relationship-integrity.txt
  ```

  **Commit**: YES | Message: `feat(world): 程序化世界生成器（NPC/关系/资源/怪物/功法）` | Files: `scripts/world/world_generator.gd`, `scripts/world/name_generator.gd`

- [x] T6. NpcBehaviorLibrary 行为库

  **What to do**:
  1. 创建 `scripts/npc/npc_behavior_library.gd`（extends RefCounted, class_name NpcBehaviorLibrary）：
     - `const BEHAVIOR_DEFS: Dictionary` — 静态行为定义字典（参考 HumanEarlyLoop.ACTION_DEFS 的结构，但更丰富）
     - 分类至少：survival(8+), social(10+), cultivation(8+), exploration(6+), conflict(8+)，总计 ≥40个行为
     - 每个行为定义包含：action_id, label, category, pressure_deltas, favor_deltas, conditions, weight, description, cooldown_hours
     - `func get_behavior(action_id: StringName) -> BehaviorAction` — 按ID获取行为
     - `func get_behaviors_by_category(category: StringName) -> Array[BehaviorAction]` — 按类别获取
     - `func get_available_behaviors(npc_state: Dictionary, current_hours: float) -> Array[BehaviorAction]` — 获取NPC当前可执行行为（过滤条件不满足和冷却中的）
     - `func get_random_behavior(category: StringName, rng: RefCounted) -> BehaviorAction` — 按类别随机获取
  2. 行为示例（social类）：
     - `chat_with_neighbor`: "与邻里闲聊" — favor_deltas {friend: +2}, pressure_deltas {survival: 0, belonging: -2}, weight 3.0, cooldown_hours 4
     - `seek_mentor_guidance`: "向师长请教" — conditions {minimum_realm: "q Condensing"}, favor_deltas {mentor: +5}, pressure_deltas {learning: -3}, weight 2.0, cooldown_hours 24
     - `trade_goods`: "市集交易" — favor_deltas {merchant: +1}, pressure_deltas {survival: -2, resource: 2}, weight 2.5, cooldown_hours 8
  3. 行为示例（cultivation类）：
     - `meditate`: "静坐冥想" — pressure_deltas {cultivation: -2}, weight 4.0, cooldown_hours 2
     - `practice_technique`: "修炼功法" — conditions {has_technique: true}, pressure_deltas {cultivation: -4, survival: 1}, weight 3.0, cooldown_hours 6
     - `breakthrough_attempt`: "尝试突破" — conditions {realm_progress >= 90}, pressure_deltas {cultivation: -8}, weight 1.0, cooldown_hours 168
  4. 所有行为使用 BehaviorAction 数据类（T3 定义），确保 to_dict/from_dict 可用
  5. 行为文本描述需要足够丰富，让NPC看起来像真人决策

  **Must NOT do**:
  - ❌ 不修改 HumanEarlyLoop（T11集成时会桥接）
  - ❌ 不在此任务创建决策引擎（T10处理）
  - ❌ 不在此任务处理NPC记忆或关系（T9/T7处理）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 大量行为定义需要设计，需要平衡游戏性
  - Skills: [`godot4-feature-dev`] — GDScript 数据定义
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: T10 | Blocked By: T3

  **References**:
  - Pattern: `scripts/modes/human/human_early_loop.gd:9-112` — ACTION_DEFS 结构（8个行为定义的参考格式）
  - Pattern: `scripts/data/behavior_action.gd` — BehaviorAction 数据类定义
  - External: 鬼谷八荒 NPC行为分类（社交/修炼/探索/交易/战斗）
  - External: 太吾绘卷 行为丰富度参考

  **Acceptance Criteria**:
  - [ ] BEHAVIOR_DEFS 包含 ≥ 40个行为定义
  - [ ] 每个类别至少有行为：survival(8+), social(10+), cultivation(8+), exploration(6+), conflict(8+)
  - [ ] `godot4-runtime_validate` 对 `npc_behavior_library.gd` 无错误
  - [ ] `get_available_behaviors()` 正确过滤条件不满足的行为
  - [ ] 所有行为可 to_dict/from_dict round-trip

  **QA Scenarios**:
  ```
  Scenario: 行为库完整性
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 NpcBehaviorLibrary 实例
      2. 遍历 BEHAVIOR_DEFS 统计总数
      3. 按 category 统计每类行为数量
      4. 断言总数 ≥ 40
      5. 断言每类 survival ≥ 8, social ≥ 10, cultivation ≥ 8, exploration ≥ 6, conflict ≥ 8
    Expected: 行为库达到最低数量阈值
    Evidence: .sisyphus/evidence/task-6-behavior-count.txt

  Scenario: 条件过滤正确性
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 NpcBehaviorLibrary 实例
      2. 构造一个低级NPC状态（realm="mortal", 无功法）
      3. 调用 get_available_behaviors(npc_state, current_hours=100.0)
      4. 断言返回列表不包含 breakthrough_attempt（需 realm_progress >= 90）
      5. 断言返回列表不包含 practice_technique（需 has_technique）
      6. 断言返回列表包含 meditate 和 chat_with_neighbor
    Expected: 条件过滤正确
    Evidence: .sisyphus/evidence/task-6-behavior-filter.txt
  ```

  **Commit**: YES | Message: `feat(npc): NPC行为库（40+行为定义，5大类别）` | Files: `scripts/npc/npc_behavior_library.gd`

- [x] T7. RelationshipNetwork 关系网系统

  **What to do**:
  1. 创建 `scripts/npc/relationship_network.gd`（extends RefCounted, class_name RelationshipNetwork）：
     - `var _edges: Dictionary = {}` — 键为 "{source_id}|{target_id}"，值为 RelationshipEdge
     - `var _index_by_source: Dictionary = {}` — source_id → Array[StringName]（关系边列表）
     - `var _index_by_target: Dictionary = {}` — target_id → Array[StringName]（关系边列表）
     - `func add_edge(edge: RelationshipEdge) -> void` — 添加关系边，更新双向索引
     - `func remove_edge(source_id: StringName, target_id: StringName) -> void` — 移除关系边
     - `func get_edge(source_id: StringName, target_id: StringName) -> RelationshipEdge` — 获取特定关系边
     - `func get_edges_for(source_id: StringName) -> Array[RelationshipEdge]` — 获取某角色所有关系边
     - `func get_favor(source_id: StringName, target_id: StringName) -> int` — 获取好感度（找不到返回0）
     - `func modify_favor(source_id: StringName, target_id: StringName, delta: int) -> void` — 修改好感度
     - `func get_relations_of_type(relation_type: StringName) -> Array[RelationshipEdge]` — 按类型查询
     - `func get_allies(character_id: StringName, threshold: int = 50) -> Array[StringName]` — 获取盟友（favor ≥ threshold）
     - `func get_enemies(character_id: StringName, threshold: int = -50) -> Array[StringName]` — 获取敌人（favor ≤ threshold）
     - `func to_dict() -> Dictionary` 和 `static func from_dict(data: Dictionary) -> RelationshipNetwork`
  2. 支持的关系类型至少7种：family, friend, rival, mentor, disciple, ally, enemy
  3. 双向关系特殊处理：family/friend/allly/enemy 可能对称，mentor/disciple 互为反关系，rival 对称

  **Must NOT do**:
  - ❌ 不修改 SimulationRunner（T11集成）
  - ❌ 不在此任务创建NPC记忆系统（T9处理）
  - ❌ 不在此任务创建决策引擎（T10处理）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 数据结构设计，索引优化
  - Skills: [`godot4-feature-dev`] — GDScript 数据结构
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: T9, T10 | Blocked By: T3

  **References**:
  - Pattern: `scripts/data/relationship_edge.gd` — RelationshipEdge 数据类
  - External: 鬼谷八荒 7类关系设计（亲人、师徒、好友、道侣、同门、仇人、恩人）

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对 `relationship_network.gd` 无错误
  - [ ] 添加、查询、修改、删除关系边功能正常
  - [ ] 双向索引正确（get_edges_for 返回完整结果）
  - [ ] modify_favor 正确 clamp 到 [-300, 300]
  - [ ] to_dict/from_dict round-trip 一致
  - [ ] 性能：1000条关系边全部查询 < 5ms

  **QA Scenarios**:
  ```
  Scenario: 关系CRUD
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 RelationshipNetwork, 添加 10 条关系边
      2. 查询 get_edges_for(source_id), 断言结果数量正确
      3. 修改 modify_favor("npc_1", "npc_2", 50), 查询 get_favor(), 断言值为 50
      4. 修改 modify_favor("npc_1", "npc_2", -400), 断言 clamp 到 -300
      5. 删除一条关系边, 查询确认已移除
    Expected: 增删改查正确
    Evidence: .sisyphus/evidence/task-7-relationship-crud.txt

  Scenario: 大规模索引性能
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 RelationshipNetwork, 添加 1000 条关系边（200个NPC，每人5条）
      2. 对每个NPC调用 get_edges_for(), 统计总耗时
      3. 断言总耗时 < 5ms
    Expected: 索引性能达标
    Evidence: .sisyphus/evidence/task-7-relationship-performance.txt
  ```

  **Commit**: YES | Message: `feat(npc): 关系网系统（7类关系+好感度+双向索引）` | Files: `scripts/npc/relationship_network.gd`

- [x] T8. 模式选择 + 角色创建 UI 场景

  **What to do**:
  1. 创建 `scenes/ui/mode_select_screen.tscn` + `scripts/ui/mode_select_screen.gd`：
     - 简洁的玩法选择页面：两个大按钮"扮演凡人"和"扮演神明"
     - 选择凡人→发射 `mode_selected(&"human")` 信号
     - 选择神明→显示"施工中，敬请期待"提示框
     - 底部显示"继续游戏"按钮（有存档时可用）
  2. 创建 `scenes/ui/char_creation_screen.tscn` + `scripts/ui/char_creation_screen.gd`：
     - **名字输入**：LineEdit 输入框，最大长度10字符，必填验证
     - **道德偏好**：连续滑块（-100 正义 到 +100 唯我），带标签"刚正 ← → 唯我"，参考太吾绘卷立场轴
     - **出生地选择**：OptionButton 下拉选择（暂用3-5个选项：山村、城镇、水乡、边塞、隐谷）
     - **开局类型**：3个按钮选择（少年/青年/成年），参考现有 OPENING_PRESETS
     - **难度选择**：3个按钮选择（简单/普通/困难）
     - **种子输入**：SpinBox（可选，-1为随机种子）
     - **确认按钮**："踏入修仙界"
     - 确认时收集所有参数，构造 CharacterCreationParams，发射 `character_created(params)` 信号
     - 所有UI元素大小合适，不重叠不遮挡，使用 MarginContainer + VBoxContainer 布局
  3. 修改 `scripts/ui/ui_root.gd`：
     - 新增 `_mode_select_screen`, `_char_creation_screen` 成员变量
     - 在 `_ready()` 中创建并添加这两个 Panel
     - 监听 `RunState.phase_changed` 信号，根据 phase 显示/隐藏对应面板
     - 转发 `mode_selected` 和 `character_created` 信号
  4. 修改 `scripts/game_root.gd`：
     - 连接 `ui_root.mode_selected` 和 `ui_root.character_created` 信号
     - 在 `_on_mode_selected()` 中设置 RunState.mode 和 phase
     - 在 `_on_character_created()` 中存储参数到 RunState.creation_params，设置 phase 为 "world_init"

  **Must NOT do**:
  - ❌ 不修改现有的 MainMenu 面板（隐藏时保持不变）
  - ❌ 不在此任务创建世界初始化UI（T12处理）
  - ❌ 不在此任务修改 SimulationRunner（T11处理）
  - ❌ 不使用美术资源，仅用 Godot 内置样式

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: UI场景创建需要视觉布局
  - Skills: [`godot4-feature-dev`] — Godot UI场景+脚本
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: T12 | Blocked By: T1

  **References**:
  - Pattern: `scripts/ui/ui_root.gd:1-80` — UI面板创建和信号连接模式
  - Pattern: `scripts/game_root.gd:30-43` — _on_new_game_requested() 信号处理模式
  - Pattern: `scripts/data/character_creation_params.gd` — CharacterCreationParams 数据类
  - Pattern: `scripts/modes/human/human_opening_builder.gd:4-8` — DEFAULT_CHARACTER_ID 等常量参考
  - Pattern: `scripts/modes/human/human_opening_builder.gd:10-112` — OPENING_PRESETS 结构参考

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对新场景和脚本无错误
  - [ ] 运行游戏，从主菜单→新游戏→模式选择→凡人→角色创建页面流畅可见
  - [ ] 角色创建页面所有控件可用，名字输入有字符限制，道德滑块有范围限制
  - [ ] 确认后 creation_params 正确传递到 GameRoot
  - [ ] 选择神明显示"施工中"提示框

  **QA Scenarios**:
  ```
  Scenario: 完整角色创建流程
    Tool: godot4-runtime_simulate_input
    Steps:
      1. 运行游戏，点击"新游戏"
      2. 在模式选择页点击"扮演凡人"
      3. 断言 RunState.phase == "char_creation"
      4. 在名字输入框输入"测试修仙者"
      5. 调整道德滑块到 50
      6. 选择出生地"城镇"
      7. 选择开局类型"少年"
      8. 点击"踏入修仙界"
      9. 断言 RunState.phase == "world_init"
      10. 断言 RunState.creation_params.character_name == "测试修仙者"
    Expected: 角色创建流程完整可走通
    Evidence: .sisyphus/evidence/task-8-char-creation-flow.txt

  Scenario: 神明模式占位提示
    Tool: godot4-runtime_simulate_input
    Steps:
      1. 在模式选择页点击"扮演神明"
      2. 断言出现"施工中"提示框
      3. 点击确认关闭提示框
      4. 断言仍在模式选择页
    Expected: 神明模式显示施工中提示
    Evidence: .sisyphus/evidence/task-8-deity-placeholder.txt

  Scenario: UI不重叠
    Tool: godot4-runtime_run_script
    Steps:
      1. 遍历角色创建页面所有可见 Control 节点
      2. 检测矩形区域重叠
      3. 断言无 Critical 级重叠（仅允许边框级别的1px重叠）
    Expected: UI元素不重叠不遮挡
    Evidence: .sisyphus/evidence/task-8-ui-no-overlap.txt
  ```

  **Commit**: YES | Message: `feat(ui): 模式选择+角色创建页面` | Files: `scenes/ui/mode_select_screen.tscn`, `scripts/ui/mode_select_screen.gd`, `scenes/ui/char_creation_screen.tscn`, `scripts/ui/char_creation_screen.gd`, `scripts/ui/ui_root.gd`, `scripts/game_root.gd`

- [x] T9. NpcMemorySystem 记忆系统

  **What to do**:
  1. 创建 `scripts/npc/npc_memory_system.gd`（extends RefCounted, class_name NpcMemorySystem）：
     - `var _memories: Dictionary = {}` — 键为 character_id，值为 Array[NpcMemoryEntry]
     - `var _max_memories_per_npc: int = 50` — 每个NPC记忆容量上限
     - `var _retention_threshold: float = 0.5` — 保留阈值，低于此值的记忆将被遗忘
     - `func add_memory(character_id: StringName, entry: NpcMemoryEntry) -> void` — 添加记忆，超出容量时按保留分数淘汰
     - `func get_memories(character_id: StringName) -> Array[NpcMemoryEntry]` — 获取某NPC所有记忆（按重要性排序）
     - `func get_recent_memories(character_id: StringName, count: int = 5) -> Array[NpcMemoryEntry]` — 获取最近N条记忆
     - `func get_memories_about(character_id: StringName, about_id: StringName) -> Array[NpcMemoryEntry]` — 获取关于特定角色的记忆
     - `func decay_memories(character_id: StringName, current_hours: float) -> void` — 衰减记忆，移除低于阈值的
     - `func get_retention_score(character_id: StringName, entry: NpcMemoryEntry, current_hours: float) -> float` — 计算保留分数
     - `func to_dict() -> Dictionary` 和 `static func from_dict(data: Dictionary) -> NpcMemorySystem`
  2. 衰减公式：`retention_score = importance / (1 + age_hours / 24.0)`，低于阈值时标记为遗忘
  3. 容量管理：超出上限时先淘汰保留分数最低的记忆
  4. 确保空记忆不占用存储

  **Must NOT do**:
  - ❌ 不在此任务集成到 SimulationRunner（T11处理）
  - ❌ 不修改 NpcMemoryEntry 数据类（T3已定义）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 记忆系统需要衰减算法和容量管理
  - Skills: [`godot4-feature-dev`] — GDScript 算法
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: T10 | Blocked By: T3, T7

  **References**:
  - Pattern: `scripts/data/npc_memory_entry.gd` — NpcMemoryEntry 数据类（importance, timestamp_hours, summary, retention计算）
  - External: 修仙模拟器 NPC记忆系统参考（重要事件保留、平凡事件衰减）

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对 `npc_memory_system.gd` 无错误
  - [ ] 添加记忆并查询功能正常
  - [ ] 衰减后低重要性记忆被移除
  - [ ] 超出容量时淘汰保留分数最低的记忆
  - [ ] to_dict/from_dict round-trip 一致
  - [ ] 50个NPC各50条记忆状态下，decay_memories 耗时 < 10ms

  **QA Scenarios**:
  ```
  Scenario: 记忆衰减与淘汰
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建 NpcMemorySystem, max = 50
      2. 为 NPC_A 添加 60 条记忆（importance 1-10, timestamp 递增）
      3. 调用 decay_memories("NPC_A", current_hours=1000.0)
      4. 断言 NPC_A 记忆数量 ≤ 50
      5. 断言剩余记忆的 retention_score ≥ threshold
    Expected: 衰减正常淘汰低分记忆
    Evidence: .sisyphus/evidence/task-9-memory-decay.txt

  Scenario: 记忆查询与过滤
    Tool: godot4-runtime_run_script
    Steps:
      1. 为 NPC_A 添加 10 条关于 NPC_B 的记忆和 5 条关于 NPC_C 的
      2. 调用 get_memories_about("NPC_A", "NPC_B")
      3. 断言返回恰好 10 条且所有条相关ID包含 NPC_B
      4. 调用 get_recent_memories("NPC_A", 5)
      5. 断言返回最新 5 条记忆
    Expected: 记忆查询正确过滤
    Evidence: .sisyphus/evidence/task-9-memory-query.txt
  ```

  **Commit**: YES | Message: `feat(npc): NPC记忆系统（衰减+容量管理+查询）` | Files: `scripts/npc/npc_memory_system.gd`

- [x] T10. NpcDecisionEngine 决策引擎

  **What to do**:
  1. 创建 `scripts/npc/npc_decision_engine.gd`（extends RefCounted, class_name NpcDecisionEngine）：
     - **核心理念**：推进粒度（小时）≠ 决策粒度（每天/每6小时），NPC不是每小时都做决策
     - `func decide_action(npc_state: Dictionary, context: Dictionary) -> Dictionary` — 主入口，返回选中的行为及原因
     - `func score_behaviors(npc_state: Dictionary, context: Dictionary, available_behaviors: Array[BehaviorAction]) -> Array[Dictionary]` — 对可用行为打分
     - `func _score_by_needs(npc_state: Dictionary, behavior: BehaviorAction) -> float` — 需求评分（压力高的分支权重大）
     - `func _score_by_relationships(npc_state: Dictionary, behavior: BehaviorAction, relationships: RelationshipNetwork) -> float` — 关系评分（社交行为受关系影响）
     - `func _score_by_memory(npc_state: Dictionary, behavior: BehaviorAction, memories: NpcMemorySystem) -> float` — 记忆评分（近期相关事件影响决策）
     - `func _score_by_personality(npc_state: Dictionary, behavior: BehaviorAction) -> float` — 性格评分（道德偏好等影响行为倾向）
     - `func get_decision_interval(npc_state: Dictionary) -> float` — 获取该NPC的决策间隔（小时），根据性格和状态变化
  2. 评分权重组合：needs_score * 0.4 + relationship_score * 0.2 + memory_score * 0.2 + personality_score * 0.2
  3. 决策间隔：
     - 少年（youth）：每12小时一次重点决策，每小时检查是否有紧急事件
     - 青年（young_adult）：每8小时一次
     - 成年（adult）：每6小时一次
     - 紧急事件（被攻击、好友来访等）可打断常规决策间隔
  4. NPC性格参数：morality（道德偏好）影响社交/攻击行为选择倾向
  5. 引用 BehaviorAction（T6）、RelationshipNetwork（T7）、NpcMemorySystem（T9）

  **Must NOT do**:
  - ❌ 不在此任务集成到 SimulationRunner（T11处理）
  - ❌ 不在决策引擎内做每小时全量重算（使用决策间隔解耦）
  - ❌ 不修改 HumanEarlyLoop（T11会桥接）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: AI决策引擎核心，需要平衡4个评分维度
  - Skills: [`godot4-feature-dev`] — GDScript 算法设计
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: T11 | Blocked By: T6, T7, T9

  **References**:
  - Pattern: `scripts/modes/human/human_early_loop.gd:331-356` — _pick_action_id() 需求驱动决策参考
  - Pattern: `scripts/modes/human/human_early_loop.gd:371-386` — _select_dominant_branch() 分支选择参考
  - Pattern: `scripts/npc/npc_behavior_library.gd` — 行为库（T6产出）
  - Pattern: `scripts/npc/relationship_network.gd` — 关系网（T7产出）
  - Pattern: `scripts/npc/npc_memory_system.gd` — 记忆系统（T9产出）
  - Pattern: `scripts/data/behavior_action.gd` — BehaviorAction 数据类

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对 `npc_decision_engine.gd` 无错误
  - [ ] 同一NPC在不同needs状态下选择不同行为（压力高→survival类行为）
  - [ ] 同一NPC在不同关系状态下选择不同行为（有好友→社交行为增多）
  - [ ] 记忆影响决策（近期被攻击→冲突行为权重增加）
  - [ ] 性格影响决策（高道德→不选择攻击性强的行为）
  - [ ] 决策间隔正确：youth=12h, young_adult=8h, adult=6h
  - [ ] 性能：100个NPC决策 < 10ms

  **QA Scenarios**:
  ```
  Scenario: 需求驱动决策
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建NPC状态: pressures={survival: 18, family: 5, learning: 3, cultivation: 3}
      2. 调用 decide_action(npc_state, context)
      3. 断言选择的行为偏向 survival 类别
      4. 修改 pressures={cultivation: 18, survival: 3}
      5. 再次调用 decide_action
      6. 断言选择的行为偏向 cultivation 类别
    Expected: 需求是主要决策驱动力
    Evidence: .sisyphus/evidence/task-10-need-driven.txt

  Scenario: 关系影响决策
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建NPC状态和RelationshipNetwork（NPC_A有好友NPC_B）
      2. 调用 decide_action(npc_state, context_with_relationship)
      3. 断言社交类行为权重高于无关系时
      4. 修改NPC_B的favor为-200（仇人）
      5. 再次调用 decide_action
      6. 断言社交类行为权重降低
    Expected: 关系状态影响行为选择
    Evidence: .sisyphus/evidence/task-10-relationship-influence.txt

  Scenario: 决策间隔正确性
    Tool: godot4-runtime_run_script
    Steps:
      1. NPC life_stage="youth", 断言 decision_interval == 12.0
      2. NPC life_stage="young_adult", 断言 decision_interval == 8.0
      3. NPC life_stage="adult", 断言 decision_interval == 6.0
    Expected: 决策间隔与年龄阶段对应
    Evidence: .sisyphus/evidence/task-10-decision-interval.txt
  ```

  **Commit**: YES | Message: `feat(npc): NPC决策引擎（需求+关系+记忆+性格四维评分）` | Files: `scripts/npc/npc_decision_engine.gd`

- [x] T11. SimulationRunner 集成重构

  **What to do**:
  1. 修改 `scripts/sim/simulation_runner.gd`：
     - **核心改动**：将 `advance_one_day()` 重构为 `advance_tick(hours_per_tick: float)` 方法，支持小时制推进
     - 引入决策间隔概念：NPC不是每小时都做决策，而是按 NpcDecisionEngine 的 decision_interval 触发
     - **时间推进**：每次 tick 调用 `TimeService.advance_hours(hours_per_tick)` 代替 `advance_day()`
     - **bootstrap 重构**：
       - 新增 `bootstrap_from_creation(creation_params: CharacterCreationParams, seed_data: WorldSeedData)` 方法
       - 内部调用 WorldGenerator.generate(seed_data) 生成世界
       - 用 creation_params 中的参数替代硬编码的 OPENING_PRESETS
       - 将生成的角色、关系、资源注入到 runtime
     - **NPC 行为循环**：
       - 在 `advance_tick` 中检查每个NPC是否到达决策间隔
       - 到达决策间隔时调用 NpcDecisionEngine.decide_action(npc_state, context)
       - 执行选中的行为，更新 pressures、relationship favor、memory
     - **事件系统保留**：保留现有 _pick_event_template_for_stage() 事件选择机制，但改为按小时触发检查
     - 新增 `var _world_generator: RefCounted` 和 `var _decision_engine: RefCounted` 和 `var _memory_system: RefCounted` 和 `var _relationship_network: RefCounted` 成员
     - 修改 `get_snapshot()` 和 `load_snapshot()` 支持新数据（creation_params, world_seed, relationship_network, memory_system）
     - 修改 `GameRoot._on_auto_advance_timeout()` 调用 `advance_tick(TimeService.hours_per_tick)` 代替 `advance_one_day()`
     - 修改 `GameRoot._setup_auto_advance_timer()` 使用固定间隔但 TimeService 的推进量根据 speed_tier 变化
  2. 保持向下兼容：
     - `advance_one_day()` 仍然存在但内部调用 `advance_tick(24.0)`
     - `bootstrap()` 仍然存在但标记为 deprecated，新代码用 `bootstrap_from_creation()`
     - 旧存档通过 SaveService migration 自动升级

  **Must NOT do**:
  - ❌ 不删除旧方法签名（向下兼容）
  - ❌ 不在 tick 中做全量NPC AI重算（只处理到达决策间隔的NPC）
  - ❌ 不硬编码种子（由 bootstrap_from_creation 参数传入）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: SimulationRunner 是核心，需要理解现有2175行逻辑
  - Skills: [`godot4-feature-dev`] — GDScript 重构
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: T13, T14, T15, T16 | Blocked By: T2, T5, T10

  **References**:
  - Pattern: `scripts/sim/simulation_runner.gd` — SimulationRunner完整代码（~2175行）
  - Pattern: `scripts/sim/simulation_runner.gd:74-97` — bootstrap() 和 reset_simulation()
  - Pattern: `scripts/sim/simulation_runner.gd:100-113` — reset_simulation() 初始化逻辑
  - Pattern: `scripts/game_root.gd:106-126` — auto_advance_timer 和 _on_auto_advance_timeout()
  - Pattern: `autoload/time_service.gd` — 小时制时间服务（T2产出）
  - Pattern: `scripts/world/world_generator.gd` — 世界生成器（T5产出）
  - Pattern: `scripts/npc/npc_decision_engine.gd` — 决策引擎（T10产出）
  - Pattern: `scripts/data/character_creation_params.gd` — 角色创建参数（T3产出）
  - Pattern: `scripts/data/world_seed_data.gd` — 世界种子数据（T3产出）

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对修改后的 `simulation_runner.gd` 和 `game_root.gd` 无错误
  - [ ] `advance_tick(1.0)` 推进1小时，NPC只在决策间隔点触发决策
  - [ ] `advance_tick(24.0)` 等同于一次 `advance_one_day()`
  - [ ] `bootstrap_from_creation()` 使用 WorldGenerator 和 CharacterCreationParams 生成世界
  - [ ] 同 seed 两次 bootstrap_from_creation 结果完全一致
  - [ ] 旧存档可通过 migration 加载

  **QA Scenarios**:
  ```
  Scenario: 小时制推进与决策间隔
    Tool: godot4-runtime_run_script
    Steps:
      1. Bootstrap 游戏世界
      2. 反复调用 advance_tick(1.0) 共 24 次
      3. 断言 TimeService.total_hours == 24.0
      4. 统计NPC决策次数，断言 < 24（决策间隔 > 1小时）
      5. 调用 advance_tick(24.0) 一次
      6. 断言当天推进后 NPC 状态有变化
    Expected: 小时制推进正确，决策按间隔触发
    Evidence: .sisyphus/evidence/task-11-hourly-tick.txt

  Scenario: 世界生成集成
    Tool: godot4-runtime_run_script
    Steps:
      1. 构造 CharacterCreationParams 和 WorldSeedData(seed=42)
      2. 调用 bootstrap_from_creation(params, seed_data)
      3. 断言 runtime_characters 不为空
      4. 断言 relationship_network 不为空
      5. 断言无固定预制ID（无 mvp_ 前缀）
    Expected: 程序化世界生成正确集成
    Evidence: .sisyphus/evidence/task-11-world-gen-integration.txt

  Scenario: 向下兼容旧存档
    Tool: godot4-runtime_run_script
    Steps:
      1. 构造 v1 格式存档（无 creation_params 等字段）
      2. 调用 load_snapshot() 加载
      3. 断言加载成功且 creation_params 等字段为默认值
      4. 断言游戏不崩溃
    Expected: 旧存档可自动迁移
    Evidence: .sisyphus/evidence/task-11-backward-compat.txt
  ```

  **Commit**: YES | Message: `feat(sim): SimulationRunner集成重构（小时制+世界生成+NPC决策循环）` | Files: `scripts/sim/simulation_runner.gd`, `scripts/game_root.gd`

- [x] T12. 世界初始化 + 时间速度控制 UI

  **What to do**:
  1. 创建 `scenes/ui/world_init_screen.tscn` + `scripts/ui/world_init_screen.gd`：
     - 世界初始化进度页面：
       - 显示世界种子（可为空，-1时自动生成显示）
       - 分阶段进度条：生成地形 → 创建NPC → 建立关系 → 放置资源 → 生成怪物 → 创建功法
       - 每个阶段显示进度百分比和描述文本
       - 完成后自动发射 `world_initialized()` 信号并过渡到主玩法界面
     - 进度更新通过 signal 接收 WorldGenerator 的进度回调
     - 不可取消（初始化过程需要完成）
  2. 创建时间速度控制 UI组件（嵌入到主玩法界面）：
     - `scripts/ui/time_control_panel.gd`：
       - 4个速度按钮：⏪(0.5时/2秒), ▶(1时/2秒), ⏩(1天/2秒), ⏩⏩(1月/2秒)
       - 当前速度显示文本
       - 当前时间显示："第X天 HH:MM"
       - 点击按钮切换 `TimeService.set_speed_tier()` 并更新显示
       - 监听 `TimeService.speed_tier_changed` 信号自动更新UI
       - 监听 `TimeService.time_advanced` 信号更新时间显示
  3. 修改 `scripts/ui/ui_root.gd`：
     - 新增 `_world_init_screen` 和 `_time_control_panel` 成员
     - 在 `_ready()` 中创建并添加
     - 根据 RunState.phase 显示/隐藏世界初始化页面
     - 在主玩法界面中嵌入时间速度控制面板

  **Must NOT do**:
  - ❌ 不在此任务创建主玩法UI布局（T13处理）
  - ❌ 不修改 SimulationRunner 的推进逻辑（T11处理）
  - ❌ 不在此任务创建角色创建UI（T8处理）

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: UI场景创建
  - Skills: [`godot4-feature-dev`] — Godot UI场景
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: T13 | Blocked By: T2, T8

  **References**:
  - Pattern: `scripts/ui/ui_root.gd` — UI面板管理
  - Pattern: `autoload/time_service.gd` — TimeService速度控制API
  - Pattern: `autoload/run_state.gd` — RunState phase 切换
  - Pattern: `scripts/world/world_generator.gd` — WorldGenerator（T5产出）

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对新场景和脚本无错误
  - [ ] 角色创建确认后显示世界初始化页面
  - [ ] 初始化进度条逐步推进并显示阶段描述
  - [ ] 初始化完成后自动过渡到主玩法界面
  - [ ] 时间速度控制面板4个按钮可用，点击切换速度
  - [ ] 时间显示正确更新（第X天 HH:MM）

  **QA Scenarios**:
  ```
  Scenario: 世界初始化进度显示
    Tool: godot4-runtime_simulate_input
    Steps:
      1. 完成角色创建流程
      2. 断言显示世界初始化页面
      3. 等待初始化完成
      4. 断言 RunState.phase == "main_play"
    Expected: 世界初始化进度可见，完成后自动过渡
    Evidence: .sisyphus/evidence/task-12-world-init-flow.txt

  Scenario: 时间速度切换
    Tool: godot4-runtime_simulate_input + godot4-runtime_run_script
    Steps:
      1. 在主玩法界面点击时间速度按钮 ⏩(1天/2秒)
      2. 断言 TimeService.speed_tier == 3
      3. 断言 TimeService.hours_per_tick == 24.0
      4. 等待2秒，断言时间推进了约24小时（1天）
      5. 切换到 ⏩⏩(1月/2秒)
      6. 断言 TimeService.speed_tier == 4
    Expected: 速度控制正确切换
    Evidence: .sisyphus/evidence/task-12-speed-control.txt

  Scenario: UI不重叠
    Tool: godot4-runtime_run_script
    Steps:
      1. 遍历世界初始化页面和时间控制面板所有可见Control
      2. 检测矩形区域重叠
      3. 断言无Critical级重叠
    Expected: UI布局正确无遮挡
    Evidence: .sisyphus/evidence/task-12-ui-no-overlap.txt
  ```

  **Commit**: YES | Message: `feat(ui): 世界初始化进度页+时间速度控制面板` | Files: `scenes/ui/world_init_screen.tscn`, `scripts/ui/world_init_screen.gd`, `scripts/ui/time_control_panel.gd`, `scripts/ui/ui_root.gd`

- [x] T13. 主玩法 UI 布局重设计

  **What to do**:
  1. 重构 `scripts/ui/ui_root.gd` 的主玩法界面布局：
     - **左侧面板（宽度约30%）**：
       - 左上方：当前NPC头像占位（80x80）+ 名字 + 简况（修为境界、年龄、位置）
       - 左上方："详情"按钮，点击展开完整角色信息面板
       - 左下方：窗口按钮组（日志 / 地图 / 世界角色 / 好感 / 背包 等，至少4个标签页按钮）
     - **右侧面板（宽度约70%）**：
       - 右上方：信息显示区（根据左下方选中标签页切换内容）
       - 右上方：默认显示日志面板
       - 右上方：地图面板、世界角色面板、好感面板、背包容器等可切换
     - **顶部时间条**：嵌入时间速度控制面板（T12产出）+ 当前日期时间显示
     - **底部事件提示**：保留现有 EventModal 功能区域
  2. 使用 HSplitContainer 实现左右分栏，左右比例约 3:7
  3. 左侧面板使用 VBoxContainer 垂直布局
  4. 右侧面板使用 TabContainer 或手动切换的 PanelContainer
  5. 确保所有面板大小合适，使用 MinimumSize 和 SizeFlag 防止重叠
  6. 修改现有的 `_build_game_ui()` 方法，重建整个游戏界面布局
  7. 保留现有信号和功能，仅重构布局结构

  **Must NOT do**:
  - ❌ 不删除现有功能（日志、角色、地图面板的信号和逻辑保留）
  - ❌ 不在此任务修改日志和地图的内容逻辑（T14处理）
  - ❌ 不在此任务修改存档逻辑（T15处理）
  - ❌ 不使用美术资源，仅用 Godot 内置样式和颜色

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: UI大规模布局重构
  - Skills: [`godot4-feature-dev`] — Godot UI布局
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 4 | Blocks: T17 | Blocked By: T11, T12

  **References**:
  - Pattern: `scripts/ui/ui_root.gd` — 完整UI代码（869行），`_build_game_ui()`, `_build_log_panel()`, `_build_character_panel()`, `_build_map_panel()`
  - Pattern: `scripts/ui/ui_root.gd:1-80` — 现有面板变量和信号定义
  - Pattern: `scripts/ui/time_control_panel.gd` — 时间控制面板（T12产出）

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对修改后的 `ui_root.gd` 无错误
  - [ ] 进入主玩法界面后UI布局正确：左侧30%、右侧70%
  - [ ] 左上方显示NPC简况（名字、境界、年龄、位置）
  - [ ] 左下方标签页按钮可点击切换右侧内容
  - [ ] 所有面板不重叠不遮挡（Critical级重叠数为0）
  - [ ] 时间速度控制正常显示在顶部

  **QA Scenarios**:
  ```
  Scenario: 主玩法UI布局验证
    Tool: godot4-runtime_run_script
    Steps:
      1. 进入主玩法界面
      2. 遍历所有可见Control节点
      3. 检测矩形重叠
      4. 断言Critical级重叠数为0
      5. 断言左侧面板宽度约30%
      6. 断言右侧面板宽度约70%
    Expected: UI布局正确无重叠
    Evidence: .sisyphus/evidence/task-13-layout-verification.txt

  Scenario: 标签页切换功能
    Tool: godot4-runtime_simulate_input
    Steps:
      1. 在左下方点击"日志"按钮
      2. 断言右侧显示日志面板
      3. 在左下方点击"地图"按钮
      4. 断言右侧显示地图面板
      5. 在左下方点击"世界角色"按钮
      6. 断言右侧显示角色列表面板
    Expected: 标签页切换正常
    Evidence: .sisyphus/evidence/task-13-tab-switching.txt

  Scenario: NPC简况信息显示
    Tool: godot4-runtime_run_script
    Steps:
      1. 进入主玩法界面并推进1天
      2. 断言左上方显示当前NPC名字
      3. 断言显示修为境界信息
      4. 断言"详情"按钮可见且可点击
    Expected: NPC简况信息正确显示
    Evidence: .sisyphus/evidence/task-13-npc-brief.txt
  ```

  **Commit**: YES | Message: `feat(ui): 主玩法界面3:7左右布局重构` | Files: `scripts/ui/ui_root.gd`

- [x] T14. 日志 + 地图面板重构

  **What to do**:
  1. 重构日志面板：
     - 时间显示改为小时制格式："第X天 HH:MM"
     - 新增按类别过滤的标签按钮（社交/修炼/探索/冲突/系统）
     - 新增按NPC过滤的按钮（显示当前交互的NPC）
     - 日志条目显示NPC名字（高亮显示，可点击查看详情）
  2. 重构地图面板：
     - 从固定catalog数据改为读取程序化生成的区域数据
     - 区域列表使用 Tree 控件显示区域层级（如：山域 → 山门、城镇、秘境）
     - 点击区域显示区域详情：名称、描述、NPC列表、资源点、怪物分布
     - 新增区域间的连接关系可视化（文字列表形式）
  3. 新增"世界角色"标签页面板：
     - 显示所有NPC列表（可按修为/好感/区域排序）
     - 点击NPC显示详情（位置、修为、关系、近期行为）
     - 使用 ItemList 控件

  **Must NOT do**:
  - ❌ 不改变日志和地图的数据源接口（仅读取方式变化）
  - ❌ 不在此任务修改主布局结构（T13处理）
  - ❌ 不添加美术资源

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: UI面板内容重构
  - Skills: [`godot4-feature-dev`] — Godot UI控件
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: YES | Wave 4 | Blocks: T17 | Blocked By: T11

  **References**:
  - Pattern: `scripts/ui/ui_root.gd` — 特别是 `_build_log_panel()`, `_build_map_panel()`, `_refresh_log()`, `_refresh_map()`
  - Pattern: `autoload/event_log.gd` — EventLog 数据源（174行）
  - Pattern: `autoload/location_service.gd` — LocationService 区域数据

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对修改后的 `ui_root.gd` 无错误
  - [ ] 日志面板显示小时制时间格式
  - [ ] 日志类别过滤按钮可用（社交/修炼/探索/冲突/系统）
  - [ ] 地图面板显示程序化生成的区域列表
  - [ ] 世界角色面板显示NPC列表，可查看详情

  **QA Scenarios**:
  ```
  Scenario: 日志过滤功能
    Tool: godot4-runtime_simulate_input
    Steps:
      1. 推进游戏1天，产生若干日志条目
      2. 点击"修炼"类别过滤按钮
      3. 断言日志只显示修炼类别的条目
      4. 点击"全部"按钮
      5. 断言所有日志条目可见
    Expected: 日志过滤正确
    Evidence: .sisyphus/evidence/task-14-log-filter.txt

  Scenario: 程序化世界地图显示
    Tool: godot4-runtime_run_script
    Steps:
      1. Bootstrap 程序化世界
      2. 查看地图面板区域列表
      3. 断言区域数量 > 0 且无固定预制ID
      4. 点击第一个区域
      5. 断言显示区域详情（名称、NPC列表）
    Expected: 程序化世界数据正确显示
    Evidence: .sisyphus/evidence/task-14-procedural-map.txt
  ```

  **Commit**: YES | Message: `feat(ui): 日志+地图面板重构（小时制+程序化世界+角色面板）` | Files: `scripts/ui/ui_root.gd`

- [x] T15. Save/Load 游戏流程重构

  **What to do**:
  1. 修改 `scripts/game_root.gd` 的 `_on_continue_requested()`：
     - 加载存档后设置正确的 RunState.phase
     - 根据 creation_params 恢复角色创建参数
     - 恢复世界种子数据
  2. 修改 `scripts/sim/simulation_runner.gd` 的 `get_snapshot()` 和 `load_snapshot()`：
     - `get_snapshot()` 新增：`creation_params`, `world_seed_data`, `relationship_network`, `npc_memories`, `speed_tier`
     - `load_snapshot()` 新增这些字段的恢复逻辑
     - 确保所有新增数据类的序列化/反序列化正确
  3. 主玩法界面新增保存按钮（带反馈提示"保存成功"）
  4. 主菜单"继续游戏"按钮显示存档信息（使用 `SaveService.get_save_info()`）
  5. 所有新增数据通过 SaveService 传入，利用版本迁移机制

  **Must NOT do**:
  - ❌ 不修改 SaveService 核心协议（T4已处理）
  - ❌ 不在此任务修改UI布局（T13处理）
  - ❌ 不破坏旧存档的可加载性

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 存档序列化全流程重构
  - Skills: [`godot4-feature-dev`] — GDScript 序列化
  - Omitted: [`godot4-debugging`] — 不是调试任务

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: T19 | Blocked By: T4, T11

  **References**:
  - Pattern: `autoload/save_service.gd` — 完整存档服务（263行）
  - Pattern: `scripts/game_root.gd:46-73` — _on_continue_requested() 存档加载
  - Pattern: `scripts/sim/simulation_runner.gd:171-202` — get_snapshot()
  - Pattern: `scripts/sim/simulation_runner.gd:205-250` — load_snapshot()

  **Acceptance Criteria**:
  - [ ] 存档→读档→关键数据（时间、角色属性、关系边数、资源点数、世界种子）完全一致
  - [ ] 含新增字段的存档可正确保存和加载
  - [ ] v1存档可自动迁移为v2并加载（无崩溃）
  - [ ] 损坏JSON存档加载返回明确错误码

  **QA Scenarios**:
  ```
  Scenario: 存读一致性
    Tool: godot4-runtime_run_script
    Steps:
      1. Bootstrap 游戏世界，推进3天
      2. 保存存档
      3. 记录关键数据：时间、NPC数、关系边数、世界种子
      4. 重新加载存档
      5. 逐一比较加载后的关键数据
      6. 断言所有数据完全一致
    Expected: 存读数据完全一致
    Evidence: .sisyphus/evidence/task-15-save-load-consistency.txt

  Scenario: v1存档迁移
    Tool: godot4-runtime_run_script
    Steps:
      1. 构造v1格式存档文件（save_version=1）
      2. 加载并断言成功，新字段用默认值填充
      3. 断言旧字段数据完整保留
    Expected: v1存档可自动迁移
    Evidence: .sisyphus/evidence/task-15-v1-migration.txt

  Scenario: 损坏存档优雅失败
    Tool: godot4-runtime_run_script
    Steps:
      1. 创建损坏JSON文件到 user://saves/corrupt.json
      2. 调用 SaveService.load_slot("corrupt")
      3. 断言 ok=false 且有明确错误码
    Expected: 损坏存档不崩溃
    Evidence: .sisyphus/evidence/task-15-corrupt-save.txt
  ```

  **Commit**: YES | Message: `feat(save): 存档/读档流程重构（新数据结构+版本迁移）` | Files: `scripts/game_root.gd`, `scripts/sim/simulation_runner.gd`

- [x] T16. CharacterPanel NPC信息重构

  **What to do**:
  1. 重构角色面板：
     - **NPC简况区**（左上方）：名字、修为境界、年龄、当前位置、"详情"按钮
     - **NPC详情面板**（右侧信息区）：基本属性、修为进度、近期行为列表、关系列表
     - 数据源：runtime_characters + RelationshipNetwork + NpcMemorySystem
  2. 新增好感面板标签页：
     - 显示当前NPC与所有相关角色的关系
     - 每行：角色名 + 关系类型 + 好感度
     - 好感度从高到低排序
  3. 左下方窗口按钮至少包含：日志、地图、世界角色、好感、背包

  **Must NOT do**:
  - ❌ 不在此任务修改主布局结构（T13处理）
  - ❌ 不添加美术资源

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: UI面板内容重构
  - Skills: [`godot4-feature-dev`] — Godot UI控件

  **Parallelization**: Can Parallel: YES | Wave 4 | Blocks: T17 | Blocked By: T11

  **References**:
  - Pattern: `scripts/ui/ui_root.gd` — _build_character_panel(), _refresh_character_panel()
  - Pattern: `scripts/npc/relationship_network.gd` — 关系数据源（T7产出）
  - Pattern: `scripts/npc/npc_memory_system.gd` — 记忆数据源（T9产出）

  **Acceptance Criteria**:
  - [ ] NPC简况显示名字、修为境界、年龄、位置
  - [ ] 点击"详情"展开完整NPC信息（属性、修为、行为、关系）
  - [ ] 好感面板显示关系条目（角色名+类型+好感度）
  - [ ] 所有面板不重叠不遮挡

  **QA Scenarios**:
  ```
  Scenario: NPC简况与详情
    Tool: godot4-runtime_simulate_input
    Steps:
      1. Bootstrap 游戏世界，推进2天
      2. 断言左上方NPC简况显示名字、境界、年龄
      3. 点击"详情"按钮
      4. 断言右侧显示NPC详情（属性+修为+行为+关系）
    Expected: NPC信息完整显示
    Evidence: .sisyphus/evidence/task-16-npc-info.txt
  ```

  **Commit**: YES | Message: `feat(ui): CharacterPanel重构（NPC简况+详情+好感面板）` | Files: `scripts/ui/ui_root.gd`

- [x] T17. UI 碰撞检测 + 布局验证

  **What to do**:
  1. 创建 `scripts/dev/ui_overlap_detector.gd`（调试工具脚本）：
     - 遍历指定 Control 节点下所有可见子节点
     - 计算所有 Rect2 的重叠情况
     - 分类重叠：Critical（大面积重叠 > 50%）、Minor（边缘重叠 < 5%）、None
     - 返回 Critical 级重叠列表（节点名+重叠区域）
  2. 创建 `scripts/dev/layout_validation.gd`（自动化验证脚本）：
     - 验证所有流程页面（主菜单、模式选择、角色创建、世界初始化、主玩法）无 Critical 级重叠
     - 验证主玩法界面左右分栏比例在 25%-35% 和 65%-75% 之间
     - 验证时间显示格式正确（匹配 "第X天 HH:MM" 正则）
     - 验证所有按钮都有对应信号处理
     - 输出结构化验证报告到 `.sisyphus/evidence/task-17-layout-report.txt`
  3. 对所有UI流程（主菜单→选凡人→创建角色→初始化→主玩法）执行自动化验证

  **Must NOT do**:
  - ❌ 不修改游戏UI代码（仅创建验证工具）
  - ❌ 不在此任务修复UI问题（如发现则记录在报告中）

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 自动化验证工具开发
  - Skills: [`godot4-feature-dev`] — GDScript 调试工具
  - Omitted: [`godot4-debugging`] — 这是验证工具，不是调试

  **Parallelization**: Can Parallel: YES | Wave 5 | Blocks: T19 | Blocked By: T13, T14, T16

  **References**:
  - Pattern: `scripts/ui/ui_root.gd` — UI面板代码
  - Pattern: `scripts/ui/mode_select_screen.gd` — 模式选择UI（T8产出）
  - Pattern: `scripts/ui/char_creation_screen.gd` — 角色创建UI（T8产出）
  - Pattern: `scripts/ui/world_init_screen.gd` — 世界初始化UI（T12产出）
  - Pattern: `scripts/ui/time_control_panel.gd` — 时间控制面板（T12产出）

  **Acceptance Criteria**:
  - [ ] `godot4-runtime_validate` 对验证工具脚本无错误
  - [ ] 主菜单页面无 Critical 级重叠
  - [ ] 角色创建页面无 Critical 级重叠
  - [ ] 世界初始化页面无 Critical 级重叠
  - [ ] 主玩法界面无 Critical 级重叠
  - [ ] 主玩法分栏比例在 25%-35% 和 65%-75% 之间

  **QA Scenarios**:
  ```
  Scenario: 全流程UI碰撞检测
    Tool: godot4-runtime_run_script
    Steps:
      1. 逐个进入所有UI阶段（菜单、模式选择、角色创建、初始化、主玩法）
      2. 对每个阶段运行 UI 碰撞检测脚本
      3. 断言所有阶段 Critical 级重叠数为 0
      4. 输出验证报告
    Expected: 所有UI页面无Critical级重叠
    Evidence: .sisyphus/evidence/task-17-ui-overlap-report.txt

  Scenario: 布局比例验证
    Tool: godot4-runtime_run_script
    Steps:
      1. 进入主玩法界面
      2. 获取左侧面板和右侧面板的尺寸
      3. 计算左侧占比 = 左侧宽度 / 总宽度
      4. 断言左侧占比在 0.25~0.35 之间
      5. 断言右侧占比在 0.65~0.75 之间
    Expected: 分栏比例正确
    Evidence: .sisyphus/evidence/task-17-layout-ratio.txt
  ```

  **Commit**: YES | Message: `feat(dev): UI碰撞检测+布局验证工具` | Files: `scripts/dev/ui_overlap_detector.gd`, `scripts/dev/layout_validation.gd`

- [x] T18. 性能预算验证 + 调优

  **What to do**:
  1. 创建 `scripts/dev/performance_benchmark.gd`（性能基准测试脚本）：
     - 场景1：200个NPC的tick性能测试
       - Bootstrap 世界（npc_count=200）
       - 连续推进 30 秒模拟（约 360 小时游戏时间，speed_tier=4）
       - 记录每个 tick 的耗时
       - 计算 p50/p95/p99 延迟
       - 断言 p95 < 50ms
     - 场景2：世界生成性能
       - 反复生成世界（npc_count=30, 100, 200）各10次
       - 记录生成耗时
       - 断言 npc_count=30 时 < 100ms, npc_count=200 时 < 500ms
     - 场景3：存档大小测试
       - 生成世界（npc_count=200），推进7天
       - 保存存档
       - 断言存档文件大小 < 1MB
     - 场景4：决策引擎性能
       - 200个NPC各执行一次决策
       - 断言总耗时 < 50ms
  2. 对发现的问题进行调优：
     - 如果 tick 性能不达标，优化决策引擎的批量处理
     - 如果世界生成慢，优化 SeededRandom 调用频率
     - 如果存档过大，压缩重复数据

  **Must NOT do**:
  - ❌ 不在此任务修改核心逻辑（仅调优性能）
  - ❌ 不降低NPC数量或世界规模来满足性能目标

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 性能调优需要深入理解瓶颈
  - Skills: [`godot4-feature-dev`] — GDScript 性能优化
  - Omitted: [`godot4-debugging`] — 这是性能验证，不是调试

  **Parallelization**: Can Parallel: YES | Wave 5 | Blocks: T19 | Blocked By: T11

  **References**:
  - Pattern: `scripts/sim/simulation_runner.gd` — SimulationRunner tick逻辑
  - Pattern: `scripts/npc/npc_decision_engine.gd` — 决策引擎（T10产出）
  - Pattern: `scripts/world/world_generator.gd` — 世界生成器（T5产出）
  - Pattern: `autoload/save_service.gd` — 存档服务

  **Acceptance Criteria**:
  - [ ] 200 NPC 模拟30秒无 fatal/error 输出
  - [ ] tick p95 延迟 < 50ms
  - [ ] 世界生成（30 NPC）< 100ms
  - [ ] 世界生成（200 NPC）< 500ms
  - [ ] 存档大小 < 1MB（200 NPC, 7天数据）

  **QA Scenarios**:
  ```
  Scenario: Tick性能基准
    Tool: godot4-runtime_run_script
    Steps:
      1. Bootstrap 世界（npc_count=200）
      2. 连续 advance_tick(12.0) 共 30 次（模拟约 360 小时）
      3. 记录每次 tick 耗时
      4. 计算 p50/p95/p99
      5. 断言 p95 < 50ms
    Expected: Tick性能达标
    Evidence: .sisyphus/evidence/task-18-tick-benchmark.txt

  Scenario: 世界生成性能
    Tool: godot4-runtime_run_script
    Steps:
      1. 生成世界（npc_count=30）10次，记录平均耗时
      2. 断言平均耗时 < 100ms
      3. 生成世界（npc_count=200）10次，记录平均耗时
      4. 断言平均耗时 < 500ms
    Expected: 世界生成性能达标
    Evidence: .sisyphus/evidence/task-18-worldgen-benchmark.txt

  Scenario: 存档大小
    Tool: godot4-runtime_run_script
    Steps:
      1. Bootstrap 世界（npc_count=200）
      2. 推进7天
      3. 保存存档
      4. 读取存档文件大小
      5. 断言 < 1MB
    Expected: 存档大小合理
    Evidence: .sisyphus/evidence/task-18-save-size.txt
  ```

  **Commit**: YES | Message: `perf(validation): 性能基准测试+调优` | Files: `scripts/dev/performance_benchmark.gd`

- [x] T19. 全流程端到端自动化验收

  **What to do**:
  1. 创建 `scripts/dev/e2e_acceptance.gd`（端到端自动化验收脚本）：
     - 测试1：完整流程走通
       - 主菜单 → 新游戏 → 选择凡人 → 角色创建（名字"测试修仙者"、道德50、出生地"城镇"、少年）→ 世界初始化 → 主玩法界面
       - 断言 RunState.phase == "main_play"
       - 断言 creation_params 正确
       - 断言 TimeService.total_hours > 0
       - 断言 runtime_characters 不为空
       - 断言 relationship_network 不为空
     - 测试2：时间速度切换
       - 在主玩法界面切换速度4次
       - 断言每次切换后 speed_tier 正确
       - 断言时间按对应速率推进
     - 测试3：NPC行为触发
       - 推进1天
       - 断言至少1个NPC有行为记录
       - 断言时间推进正确
     - 测试4：存档/读档一致
       - 保存存档
       - 记录关键数据
       - 加载存档
       - 断言所有关键数据一致
     - 测试5：UI标签页切换
       - 依次切换所有标签页（日志、地图、世界角色、好感）
       - 断言每次切换后右侧面板内容正确
     - 测试6：不同seed世界差异
       - 两个不同seed生成世界
       - 断言NPC主键集合差异率 > 50%
  2. 所有测试输出结构化报告到 `.sisyphus/evidence/task-19-e2e-report.txt`

  **Must NOT do**:
  - ❌ 不在此任务修改游戏逻辑（仅验收）
  - ❌ 不跳过任何验收测试项

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 端到端验收需要理解全流程
  - Skills: [`godot4-feature-dev`] — GDScript 测试
  - Omitted: [`godot4-debugging`] — 这是验收，不是调试

  **Parallelization**: Can Parallel: NO | Wave 5 | Blocks: — | Blocked By: T17, T18, T15

  **References**:
  - All previous tasks' acceptance criteria
  - Pattern: `scripts/dev/smoke_runner.gd` — 现有烟雾测试运行器
  - Pattern: `scripts/dev/ui_smoke.gd` — 现有UI烟雾测试

  **Acceptance Criteria**:
  - [ ] 完整流程走通测试通过
  - [ ] 时间速度切换测试通过
  - [ ] NPC行为触发测试通过
  - [ ] 存档/读档一致性测试通过
  - [ ] UI标签页切换测试通过
  - [ ] 不同seed世界差异测试通过

  **QA Scenarios**:
  ```
  Scenario: 端到端完整流程
    Tool: godot4-runtime_run_project + godot4-runtime_simulate_input + godot4-runtime_run_script
    Steps:
      1. 运行游戏
      2. 自动化输入完成"菜单→选凡人→创建角色→初始化→主玩法"
      3. 断言 RunState.phase == "main_play"
      4. 推进1天，断言NPC有行为记录
      5. 切换速度4次，断言每次正确
      6. 保存存档，加载存档
      7. 断言关键数据一致
      8. 切换所有标签页
    Expected: 全流程自动化通过
    Evidence: .sisyphus/evidence/task-19-e2e-full-flow.txt

  Scenario: 两局不同seed
    Tool: godot4-runtime_run_script
    Steps:
      1. 用seed=111生成世界，记录NPC ID集合A
      2. 用seed=222生成世界，记录NPC ID集合B
      3. 计算差异率 = |A - B| / |A ∪ B|
      4. 断言差异率 > 0.5
    Expected: 不同seed生成不同世界
    Evidence: .sisyphus/evidence/task-19-seed-diversity.txt
  ```

  **Commit**: YES | Message: `feat(dev): 端到端自动化验收脚本` | Files: `scripts/dev/e2e_acceptance.gd`

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.**
- [x] F1. Plan Compliance Audit — oracle (APPROVE with notes: 7 spec nitpicks, all core functionality present)
- [x] F2. Code Quality Review — unspecified-high (APPROVE after fixing 3 critical issues)
- [x] F3. Real Manual QA — unspecified-high (APPROVE after fixing world_init_screen crash)
- [x] F4. Scope Fidelity Check — deep (APPROVE with notes: pre-existing deity/combat content, not new scope creep)

## Commit Strategy
- Wave 1: `feat(flow): 扩展流程状态机 + 小时制时间 + 数据模型 + 存档协议`
- Wave 2: `feat(world): 程序化世界生成 + 行为库 + 关系网 + 角色创建UI`
- Wave 3: `feat(npc): 记忆系统 + 决策引擎 + 模拟集成 + 初始化UI`
- Wave 4: `feat(ui): 主玩法布局 + 面板重构 + 存读流程 + NPC信息面板`
- Wave 5: `fix(validation): 碰撞检测 + 性能预算 + 端到端验收`

## Success Criteria
1. 完整的"菜单→选凡人→创建角色→世界初始化→主玩法"流程可自动化走通
2. 小时制4档速度控制可用，时间推进量符合预期
3. 每次新游戏世界和NPC全部程序化生成，seed可复现
4. NPC行为库≥40个行为定义，关系系统≥5种关系类型
5. 主玩法UI无Critical级重叠/遮挡
6. 存档V2协议可用，round-trip一致性验证通过
7. 200 NPC规模下30秒模拟无error，性能达标
8. 神明模式仅保留入口占位，无内容扩展
# Learnings

## 2026-04-19 (Task 11 行为链移动接线)
- 把“移动”放在 `SimulationRunner` 的行为解析层最稳妥：`_resolve_human_mode_day()` / `_resolve_character_actions()` 都能拿到动作语义，同时可统一走 `LocationService.set_character_region()`。
- human 侧可按 action_id 识别 travel-like 行为（如 `seek_master/visit_sect/ask_for_guidance`），非 travel 行为直接返回不移动，能保持“非移动动作不改变位置”。
- movement 日志应独立于 action 日志：单独 `category=movement`，并在 trace 写入 `movement_from_region_id/movement_to_region_id/movement_cause`，便于时间线筛选与验收。

## 2026-04-19 (Task 11 修复复验)
- 复验确认 `simulation_runner.gd` 内 human/NPC 移动均通过 `LocationService.set_character_region()`，不存在 human mode 直接写 `region_id` 的旁路更新。
- human 冒烟（`day_tick human seed=42 days=4`）中，非 travel 的 `study_classics/support_family` 不产生日志移动；travel 的 `seek_master` 产出 `movement` 事件，trace 含 from/to/cause。

## 2026-04-19 (LocationService 地图崩溃修复)
- `WorldDataCatalog` 是强类型 Resource（`class_name WorldDataCatalog` + `@export var regions`），`get_all_regions()` 应优先通过 typed API 读取 `regions`，而非依赖字典式访问假设。
- 在 Godot 4 中，`Resource.get()` 只接收一个参数；写成 `resource.get("prop", fallback)` 会触发运行时错误。需要用辅助函数包装 fallback 逻辑。

## 2026-04-19 (task10 地图烟测去脆弱化)
- 地图 smoke 应断言稳定结构条件（MapPanel 可见、Tree 存在、详情 RichTextLabel 存在、区域项数量>=1），避免依赖动态生成的内部节点路径。
- 若直接实例化 `ui_root.tscn` 做 smoke，需要先在脚本内最小化引导 `SimulationRunner.bootstrap()` 以绑定 `LocationService`，否则地图树会为空并导致误报。

## 2026-04-19 (T5 事件频控阈值收口)
- 仅靠两类普通模板（`festival/selection`）无法稳定达成“200 tick 单模板占比 <=35%”；最小可行方案是补充少量普通模板而非重写选择算法。
- 保留既有 `_pick_event_template_for_stage` 的冷却/频控/分层回退策略，只扩普通模板池到 5 个后，`event_diversity` 200 tick 可稳定落到 `max_ratio=0.335` 且窗口重复阈值通过。
- 正统冲突模板仍保持优先通道，在分布统计里单独剔除，避免冲突剧情节奏被普通模板频控指标误伤。

## 2026-04-19
- 当前启动链是 `project.godot -> game_root.gd -> simulation_runner.bootstrap()`；没有正式菜单路由。
- `UIRoot` 目前只构建最小状态/操作/日志，没有主菜单与模式切换入口。
- `RunState.set_mode()` 已存在，但主要由 dev smoke 脚本使用。
- New Game/Continue 的语义必须强制分离；New 需要随机 seed + 全量 reset，Continue 只能走快照恢复。

## 2026-04-19 (Update)
- 主菜单路由已添加：`GameRoot` 默认进入 `menu` phase，不再自动 `bootstrap()`。
- `UIRoot` 增加 `MainMenuPanel`，提供 `human` / `deity` 新游戏入口与 `continue` 占位。
- 启动链改为：`GameRoot` 等待 -> `UIRoot` 触发 `menu_new_game_requested` -> `GameRoot` 推进 `RunState` 模式与阶段，并执行 `bootstrap()`。
- 不再会有未选择前就进入模拟、甚至自动过天的情况。

## 2026-04-19 (Save Protocol Task 2)
- SaveService 已升级为 `user://saves/{slot}.json` 协议，payload 固定包含 `save_version/slot_id/timestamp/data`。
- 保留了兼容入口：`save_game(data)` / `load_game()` 继续可用，内部映射到 `default` 槽位。
- 写入流程使用临时文件 `*.tmp` + rename 覆盖正式文件，实现最小原子写策略。
- 加载流程引入结构校验与错误码：缺字段、类型不匹配、版本不支持、槽位不匹配、JSON 解析失败都会返回明确失败状态。
- Godot JSON 反序列化的数字可能出现为浮点（例如 `1.0`）；协议校验需按“整数语义”校验并归一化为 int，避免误判正常存档。

## 2026-04-19 (Simulation Snapshot Task 3)
- `SimulationRunner` 已增加 `get_snapshot()` / `load_snapshot(snapshot)`，并采用与 SaveService 一致的显式结果结构：`ok/error/context`。
- 快照最小字段已覆盖 `seed/mode/time/runtime_characters/world_feedback/log_cursor`，并附带 `event_log_entries` 以支持后续 Continue 的最小闭环恢复。
- 为确保 JSON 可序列化稳定性，新增 `_normalize_snapshot_value()`，统一把 `StringName` 与 `Packed*Array` 归一化为基础类型。
- 恢复流程先校验再应用，缺字段/类型错误/日志游标不一致都会返回显式失败，避免崩溃。

## 2026-04-19 (Task 4 New/Continue 语义)
- `SimulationRunner.bootstrap()` 与 `reset_simulation()` 默认参数已从固定值改为“未指定种子时自动生成运行时种子”，同时保留显式 `bootstrap(seed)` 用于测试注入固定种子。
- `GameRoot._on_new_game_requested()` 明确走“新世界分支”：每次调用 `bootstrap()` 不传 seed，由 Runner 自行生成新 seed。
- `GameRoot._on_continue_requested()` 已接入快照恢复语义：读取 `SaveService.load_game()` 后优先使用 `simulation_snapshot` 字段调用 `load_snapshot()`，并兼容直接以快照为根的旧结构。
- 通过运行时脚本验证：连续两次 New Game 指纹不同；在中途推进一天后执行 Continue 可恢复到保存时指纹。 

## 2026-04-19 (Task 4 收口补充)
- 为避免 Continue 后日志指纹被额外系统日志污染，`_on_continue_requested()` 不再在恢复成功后追加额外 `EventLog.add_entry`，改为仅依赖快照重放结果。
- `GameRoot` 新增 `_extract_snapshot_from_save_payload()`，把 Continue 的“包装快照优先 + legacy 根快照兼容”提取为单一入口，降低分支歧义。
- `_setup_auto_advance_timer()` 增加旧 timer 清理，确保重复 New/Continue 不会叠加多个自动推进定时器，保持“新开局全量重置”语义稳定。

## 2026-04-19 (Task 5 事件去重与频控)
- 在 `SimulationRunner` 事件选择层引入本地历史 `_event_template_history`，仅记录 `template_id/event_type/day/feedback_stage/orthodox_conflict_kind`，不改事件系统结构。
- `_pick_event_template_for_stage()` 改为“候选构建 + 评分决策 + 分层回退”：优先满足冷却与频控，最后才放宽约束。
- 同模板频控按 stage 维度统计：10 tick 窗口内同模板最多 2 次（普通模板达成），避免 warning/response/aftermath 互相污染计数。
- 增加 aftermath 的 festival 饱和抑制：当同 stage 下 festival 在窗口内已达上限时，优先偏向非 festival 模板，减轻 aftermath 节庆连续刷屏。
- 保留正统冲突模板（`investigation/suppression`）的强制选择优先级与既有反馈链行为，不改冲突触发逻辑。

## 2026-04-19 (Task 6 UI Log Presentation)
- 日志区已改造为三层视图（Summary/Standard/Detail）。
- `Summary` 视图会将连续的相同事件（相同 title, location, result, actor）进行聚合，通过 `(xN)` 显示数量，减少同质信息刷屏。
- 引入了动态生成 `actor_ids` 和 `category` 筛选器的下拉菜单，菜单项会在 `_refresh_log()` 时通过扫描缓存中的新事件进行自动更新。
- 采用代码动态构建 Godot 原生控件（`HBoxContainer` 与 `OptionButton`），无需修改底层场景文件即可扩展 UI。

## 2026-04-19 (Task 8 Character UI)
- 通过代码动态构建包含左右侧边栏 (`HSplitContainer`, `VSplitContainer`) 的角色情报库面板 (`CharacterPanel`)。
- `CharacterService` 提供的 read-only 数据 (`get_roster()`, `get_character_view()`) 能够被 UI 直接利用，并且自带视野过滤 (`human`/`deity` visible)。
- 返回的属性（如 `morality_tags`）可能已经是 `PackedStringArray`，在 Godot 4 中直接使用 `",".join()` 处理非常方便。
- UI 不包含任何角色修改功能，所有状态仅用于展示。


## 2026-04-19 (Task 12 解析错误修复)
- Godot 4 的 GDScript 在本项目里对 `var x := ...` 的推断更严格；当返回值是未显式类型方法结果时（如 `get_character_view()/load_game()`），需要显式写成 `var x: Dictionary = ...` 以避免 parser 在 headless 下直接失败。
- 对 `Array[Dictionary]` 也应显式注解（如 roster），否则在某些调用路径上会出现“无法推断类型”的解析报错。
- 先用 `lsp_diagnostics` 清零解析错误，再跑 headless smoke，能把“语法/类型问题”与“业务断言问题”稳定分离。


## 2026-04-19 (Task 12 AC04/AC07/AC08 收口)
- T12 e2e 的关键在“先确保 UI 面板已构建，再做断言”：`_ensure_ui_panels_ready()` 能避免把节点尚未建成误判为业务失败。
- AC07 更稳的做法是“遍历 roster 找到至少一个 detail 非空且 timeline 非空的角色”，避免首个角色偶发无时间线导致假阴性。
- 在 headless 环境里给 `UIRoot` 注入 `EventLog/TimeService/RunState/CharacterService/LocationService` 引用，可避免 `_refresh_*` 读取空单例引发噪声错误，从而让断言只反映业务结果。


## 2026-04-19 (Final Wave F4 修复：证据补齐与范围收敛)
- T5 证据应采用“原始冒烟输出 + 结构化摘要”双文件：`task-5-event-diversity.txt` 保留完整命令输出，`task-5-event-diversity.json` 仅从该原始文件提炼，确保可审计与可复核。
- 在当前环境中可执行为 `/home/mars/.local/bin/godot`，不是 `godot4`；证据脚本调用需以实际可用命令为准，避免产生“命令不存在”的无效证据。
- 范围收敛时应只删明确计划外产物（task13/14/15），并保留 T5/T12 与 Final Wave 相关证据，避免误伤计划内链路。


## 2026-04-19 (F4 范围收敛第二轮清理)
- 对 scope fidelity 收敛，优先策略是“先恢复其他计划的已跟踪改动，再删除明确无关的未跟踪产物”，比直接全量 clean 风险更低。
- T5/T12 证据链（`task-5-*`、`task-12-*`）在清理过程中应白名单保护，避免误删后重新采证。

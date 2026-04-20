# Decisions

## 2026-04-19 (Task 11 行为链移动接线)
- 决定不在 `human_early_loop.gd` 改写 `region_id`，而是在 `SimulationRunner` 行为结算阶段统一调用 `LocationService`，确保“位置变更唯一入口”不被 UI 或模式代码绕过。
- 决定将 movement 记录为独立事件类别（`category=movement`），而不是塞入 `human_action/npc_action` 文本，便于日志筛选与 timeline 对齐。

## 2026-04-19 (Task 11 修复复验)
- 本轮不继续扩展到 UI/存档/地图层，仅维持 `simulation_runner.gd` 行为层最小变更面；验证通过后不再追加结构性重构。

## 2026-04-19 (LocationService 地图崩溃修复)
- 本次仅修改 `autoload/location_service.gd`：保留 `get_all_regions()` 返回 shape 与可见性过滤逻辑，不改 UI 面板与地图树组装流程。

## 2026-04-19 (task10 地图烟测去脆弱化)
- 选择在 `scripts/dev/task10_smoke.gd` 增加 `scenario=map` 分支来承载稳定地图断言，不改 `ui_root.gd` 地图实现，避免把测试脆弱性转化为产品代码改动。

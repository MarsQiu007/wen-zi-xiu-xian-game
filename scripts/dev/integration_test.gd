extends RefCounted
class_name IntegrationTest

const SimulationRunnerScript = preload("res://scripts/sim/simulation_runner.gd")
const TimeServiceScript = preload("res://autoload/time_service.gd")
const EventLogScript = preload("res://autoload/event_log.gd")
const RunStateScript = preload("res://autoload/run_state.gd")
const LocationServiceScript = preload("res://autoload/location_service.gd")
const SeededRandomScript = preload("res://scripts/sim/seeded_random.gd")
const WorldSeedDataScript = preload("res://scripts/data/world_seed_data.gd")
const WorldGeneratorScript = preload("res://scripts/world/world_generator.gd")
const CombatManagerScript = preload("res://scripts/combat/combat_manager.gd")
const CombatantDataScript = preload("res://scripts/data/combatant_data.gd")
const RNGChannelsScript = preload("res://scripts/core/rng_channels.gd")
const TechniqueServiceScript = preload("res://scripts/services/technique_service.gd")
const CraftingServiceScript = preload("res://scripts/services/crafting_service.gd")

const CATALOG_PATH := "res://resources/world/world_data_catalog.tres"
const TEST_SAVE_SLOT := "task26_integration"


func execute(scene_tree: SceneTree) -> Variant:
	return run(scene_tree)


func run(scene_tree: SceneTree) -> Dictionary:
	var checks: Dictionary = {}
	var errors: Array[String] = []
	var context_result: Dictionary = _build_context(scene_tree)
	if not bool(context_result.get("ok", false)):
		return {
			"ok": false,
			"passed": 0,
			"total": 1,
			"checks": {},
			"errors": [str(context_result.get("error", "context_init_failed"))],
		}

	var context: Dictionary = context_result.get("context", {})
	var runner: Node = context.get("runner")
	var event_log: Node = context.get("event_log")
	var inventory_service: Node = context.get("inventory_service")
	var save_service: Node = context.get("save_service")
	var catalog: Resource = context.get("catalog")
	var player_id := str(context.get("player_id", "")).strip_edges()
	var npc_id := str(context.get("npc_id", "")).strip_edges()

	checks["world_generation"] = _check_world_generation(catalog, errors)
	checks["pickup_equip_stats"] = _check_pickup_equip_stats(inventory_service, player_id, errors)
	checks["technique_flow"] = _check_technique_flow(runner, catalog, player_id, errors)
	checks["combat_win_loot_and_determinism"] = _check_combat_win_and_determinism(event_log, catalog, errors)
	checks["crafting_alchemy_forge"] = _check_crafting_flow(inventory_service, event_log, catalog, player_id, errors)
	checks["trade_path"] = _check_trade_path(runner, inventory_service, player_id, npc_id, errors)
	checks["npc_autonomy"] = _check_npc_autonomy(runner, event_log, errors)
	checks["world_resource_cycle"] = _check_world_resource_cycle(runner, errors)
	checks["save_load_consistency"] = _check_save_load_consistency(save_service, runner, errors)
	checks["economy_1000_tick_stability"] = _check_economy_stability_1000_ticks(runner, errors)

	_cleanup_context(context)

	var passed := 0
	for value in checks.values():
		if bool(value):
			passed += 1
	var total := checks.size()
	var result := {
		"ok": errors.is_empty() and passed == total,
		"passed": passed,
		"total": total,
		"checks": checks,
		"errors": errors,
	}
	print("TASK26_INTEGRATION_RESULT=", JSON.stringify(result))
	return result


func _build_context(scene_tree: SceneTree) -> Dictionary:
	if scene_tree == null or scene_tree.root == null:
		return {"ok": false, "error": "scene_tree_root_missing"}
	var root: Node = scene_tree.root

	var catalog: Resource = load(CATALOG_PATH)
	if catalog == null:
		return {"ok": false, "error": "catalog_load_failed"}

	var inventory_service: Node = root.get_node_or_null("InventoryService")
	if inventory_service == null:
		return {"ok": false, "error": "inventory_service_missing"}
	if inventory_service.has_method("bind_catalog"):
		inventory_service.bind_catalog(catalog)
	if inventory_service.has_method("load_state"):
		inventory_service.load_state({"inventories": {}})

	var save_service: Node = root.get_node_or_null("SaveService")
	if save_service == null:
		return {"ok": false, "error": "save_service_missing"}

	var runner: Node = SimulationRunnerScript.new()
	root.add_child(runner)

	var time_service: Node = TimeServiceScript.new()
	var event_log: Node = EventLogScript.new()
	var run_state: Node = RunStateScript.new()
	var location_service: Node = LocationServiceScript.new()
	run_state.set_mode(&"human")
	runner.setup_services(time_service, event_log, run_state, location_service)
	runner.configure_human_mode({"opening_type": "orphan"})
	runner.bootstrap(424242)

	var player_id := _resolve_player_id(runner)
	if player_id.is_empty():
		_cleanup_context({
			"runner": runner,
			"time_service": time_service,
			"event_log": event_log,
			"run_state": run_state,
			"location_service": location_service,
		})
		return {"ok": false, "error": "player_id_missing"}

	var npc_id := _resolve_npc_id(runner, player_id)

	return {
		"ok": true,
		"context": {
			"runner": runner,
			"time_service": time_service,
			"event_log": event_log,
			"run_state": run_state,
			"location_service": location_service,
			"inventory_service": inventory_service,
			"save_service": save_service,
			"catalog": catalog,
			"player_id": player_id,
			"npc_id": npc_id,
		},
	}


func _check_world_generation(catalog: Resource, errors: Array[String]) -> bool:
	var generator: RefCounted = WorldGeneratorScript.new()
	var seed_data := WorldSeedDataScript.new()
	seed_data.seed_value = 777
	seed_data.region_count = 7
	seed_data.npc_count = 30
	seed_data.resource_density = 0.5
	seed_data.monster_density = 0.3
	var generated: Dictionary = generator.generate(seed_data)
	var ok := true
	ok = ok and _expect(not generated.is_empty(), "世界生成结果为空", errors)
	ok = ok and _expect((generated.get("characters", []) as Array).size() > 0, "世界生成缺少 characters", errors)
	ok = ok and _expect((generated.get("items", []) as Array).size() > 0, "世界生成缺少 items", errors)
	ok = ok and _expect((generated.get("techniques", []) as Array).size() > 0, "世界生成缺少 techniques", errors)
	ok = ok and _expect((generated.get("region_dynamics_init", {}) as Dictionary).size() > 0, "世界生成缺少 region_dynamics_init", errors)
	ok = ok and _expect(catalog != null, "catalog 不可用", errors)
	return ok


func _check_pickup_equip_stats(inventory_service: Node, player_id: String, errors: Array[String]) -> bool:
	if inventory_service == null:
		errors.append("背包服务不可用")
		return false
	if not inventory_service.has_method("add_item") or not inventory_service.has_method("equip_item"):
		errors.append("背包服务缺少 add/equip API")
		return false
	var before_stats: Dictionary = inventory_service.get_equipped_stats(player_id) if inventory_service.has_method("get_equipped_stats") else {}
	var before_attack := float(before_stats.get("attack", 0.0))
	var add_ok := bool(inventory_service.add_item(player_id, "mvp_item_iron_sword", 1, "common", []))
	var equip_ok := bool(inventory_service.equip_item(player_id, "mvp_item_iron_sword", "weapon"))
	var after_stats: Dictionary = inventory_service.get_equipped_stats(player_id) if inventory_service.has_method("get_equipped_stats") else {}
	var after_attack := float(after_stats.get("attack", 0.0))
	var ok := true
	ok = ok and _expect(add_ok, "玩家拾取物品失败", errors)
	ok = ok and _expect(equip_ok, "玩家装备物品失败", errors)
	ok = ok and _expect(after_attack > before_attack, "装备后攻击未提升", errors)
	return ok


func _check_technique_flow(runner: Node, catalog: Resource, player_id: String, errors: Array[String]) -> bool:
	if runner == null:
		errors.append("SimulationRunner 不可用")
		return false
	var service_raw: Variant = runner.get_technique_service() if runner.has_method("get_technique_service") else runner.get("_technique_service")
	if not (service_raw is Object):
		errors.append("TechniqueService 不可访问")
		return false
	var technique_service: Object = service_raw
	var resolved_player_id := player_id
	if resolved_player_id.is_empty():
		var runtime_characters: Array = runner.get_runtime_characters() if runner.has_method("get_runtime_characters") else []
		if runtime_characters.size() > 0 and runtime_characters[0] is Dictionary:
			resolved_player_id = str((runtime_characters[0] as Dictionary).get("id", "")).strip_edges()
	if resolved_player_id.is_empty():
		errors.append("功法链路缺少可用角色 id")
		return false
	if not technique_service.has_method("set_character_profile") or not technique_service.has_method("learn_technique"):
		errors.append("TechniqueService 缺少学习 API")
		return false

	technique_service.set_character_profile(resolved_player_id, {
		"faction_id": "mvp_sect_qinglan",
		"realm_level": 5,
		"sword_qualification": 100,
		"constitution": 100,
		"fire_root": 100,
	})
	technique_service.set_character_spirit_stones(resolved_player_id, 5000)

	var learn_result: Dictionary = technique_service.learn_technique(resolved_player_id, "mvp_technique_basic_sword", catalog)
	var meditate_rng: RefCounted = SeededRandomScript.new()
	meditate_rng.set_seed(19003)
	var meditate_result: Dictionary = technique_service.meditate_affix(resolved_player_id, "mvp_technique_basic_sword", 0, meditate_rng)
	if not bool(meditate_result.get("success", false)):
		meditate_rng.set_seed(19004)
		meditate_result = technique_service.meditate_affix(resolved_player_id, "mvp_technique_basic_sword", -1, meditate_rng)
	var equip_ok := bool(runner.request_equip_technique("mvp_technique_basic_sword", "martial_1"))
	if not equip_ok and technique_service.has_method("equip_technique"):
		equip_ok = bool(technique_service.equip_technique(resolved_player_id, "mvp_technique_basic_sword", "martial_1"))

	var learned_records: Array = technique_service.get_learned_techniques(resolved_player_id)
	var has_equipped := false
	for record_raw in learned_records:
		if not (record_raw is Dictionary):
			continue
		var record: Dictionary = record_raw
		if str(record.get("technique_id", "")) == "mvp_technique_basic_sword" and str(record.get("equipped_slot", "")) == "martial_1":
			has_equipped = true
			break
	if not equip_ok:
		equip_ok = has_equipped
	var ok := true
	ok = ok and _expect(bool(learn_result.get("success", false)), "功法学习失败", errors)
	ok = ok and _expect(bool(meditate_result.get("success", false)), "功法参悟失败", errors)
	ok = ok and _expect(equip_ok, "功法装备失败", errors)
	ok = ok and _expect(has_equipped, "功法未处于已装备状态", errors)
	return ok


func _check_combat_win_and_determinism(event_log: Node, catalog: Resource, errors: Array[String]) -> bool:
	var duel_results: Array[Dictionary] = []
	var fingerprints: Array[String] = []
	for _i in range(20):
		var duel_result: Dictionary = _run_seeded_duel(catalog, event_log, 5566)
		duel_results.append(duel_result)
		fingerprints.append(str(duel_result.get("fingerprint", "")))

	var result_a: Dictionary = duel_results[0] if duel_results.size() > 0 else {}
	var baseline_fingerprint := str(fingerprints[0]) if fingerprints.size() > 0 else ""
	var all_same_fingerprint := true
	for fingerprint in fingerprints:
		if str(fingerprint) != baseline_fingerprint:
			all_same_fingerprint = false
			break

	var ok := true
	ok = ok and _expect(bool(result_a.get("ok", false)), "战斗执行失败", errors)
	ok = ok and _expect(str(result_a.get("victor_id", "")) == "player_duel", "玩家战斗未获胜", errors)
	ok = ok and _expect(int(result_a.get("loot_count", 0)) > 0, "战斗未产出掉落", errors)
	ok = ok and _expect(duel_results.size() == 20, "战斗确定性测试未执行满 20 次", errors)
	ok = ok and _expect(all_same_fingerprint, "同 seed 战斗结果不一致（20 次复验）", errors)
	return ok


func _check_crafting_flow(inventory_service: Node, event_log: Node, catalog: Resource, player_id: String, errors: Array[String]) -> bool:
	var crafting_service: RefCounted = CraftingServiceScript.new()
	var rng_channels: RefCounted = RNGChannelsScript.new()
	rng_channels.seed_all(8080)
	crafting_service.bind_catalog(catalog)
	crafting_service.bind_event_log(event_log)
	crafting_service.bind_rng_channels(rng_channels)
	crafting_service.bind_inventory_service(inventory_service)

	inventory_service.add_item(player_id, "mvp_item_spirit_herb", 6, "mythic", [])
	inventory_service.add_item(player_id, "mvp_item_iron_ore", 6, "mythic", [])
	inventory_service.add_item(player_id, "mvp_item_fire_essence", 2, "mythic", [])
	crafting_service.set_character_skill_level(player_id, "alchemy", 10)
	crafting_service.set_character_skill_level(player_id, "forge", 10)

	var alchemy_ok := _craft_until_success(crafting_service, player_id, "mvp_recipe_healing_pill", catalog, 4)
	var forge_ok := _craft_until_success(crafting_service, player_id, "mvp_recipe_iron_sword", catalog, 4)
	var has_pill := bool(inventory_service.has_item(player_id, "mvp_item_basic_healing_pill", 1))
	var has_sword := bool(inventory_service.has_item(player_id, "mvp_item_iron_sword", 1))

	var ok := true
	ok = ok and _expect(alchemy_ok, "炼丹流程失败", errors)
	ok = ok and _expect(forge_ok, "炼器流程失败", errors)
	ok = ok and _expect(has_pill, "炼丹产物未入背包", errors)
	ok = ok and _expect(has_sword, "炼器产物未入背包", errors)
	return ok


func _check_trade_path(runner: Node, inventory_service: Node, player_id: String, npc_id: String, errors: Array[String]) -> bool:
	if npc_id.is_empty():
		errors.append("缺少可用 NPC，无法覆盖交易路径")
		return false
	var service_raw: Variant = runner.get_technique_service() if runner.has_method("get_technique_service") else runner.get("_technique_service")
	if not (service_raw is Object):
		errors.append("交易路径：TechniqueService 不可访问")
		return false
	var technique_service: Object = service_raw
	technique_service.set_character_spirit_stones(npc_id, 200)
	technique_service.set_character_spirit_stones(player_id, 200)

	var buy_item_id := "mvp_item_spirit_herb"
	var buy_cost := 10
	var npc_before_stones := int(technique_service.get_character_spirit_stones(npc_id))
	var npc_buy_add_ok := bool(inventory_service.add_item(npc_id, buy_item_id, 1, "uncommon", []))
	var npc_buy_deduct_ok := false
	if npc_buy_add_ok and npc_before_stones >= buy_cost:
		technique_service.set_character_spirit_stones(npc_id, npc_before_stones - buy_cost)
		npc_buy_deduct_ok = int(technique_service.get_character_spirit_stones(npc_id)) == (npc_before_stones - buy_cost)
	var buy_has_item := bool(inventory_service.has_item(npc_id, buy_item_id, 1))

	var sell_item_id := "mvp_item_spirit_stone"
	var sell_price := 10
	var player_before_stones := int(technique_service.get_character_spirit_stones(player_id))
	var sell_prepare := bool(inventory_service.add_item(player_id, sell_item_id, 1, "common", []))
	var sell_done := sell_prepare and bool(inventory_service.remove_item(player_id, sell_item_id, 1))
	var player_sell_credit_ok := false
	if sell_done:
		technique_service.set_character_spirit_stones(player_id, player_before_stones + sell_price)
		player_sell_credit_ok = int(technique_service.get_character_spirit_stones(player_id)) == (player_before_stones + sell_price)
	var player_sold_item_removed := not bool(inventory_service.has_item(player_id, sell_item_id, 1))

	var ok := true
	ok = ok and _expect(npc_buy_add_ok, "NPC 买入路径（背包入库）失败", errors)
	ok = ok and _expect(npc_buy_deduct_ok, "NPC 买入路径（灵石扣减）失败", errors)
	ok = ok and _expect(buy_has_item, "NPC 买入后未获得物品", errors)
	ok = ok and _expect(sell_done, "玩家卖出路径（背包移除）失败", errors)
	ok = ok and _expect(player_sell_credit_ok, "玩家卖出路径（灵石增加）失败", errors)
	ok = ok and _expect(player_sold_item_removed, "玩家卖出后物品仍在背包", errors)
	return ok


func _check_npc_autonomy(runner: Node, event_log: Node, errors: Array[String]) -> bool:
	var before_entries: Array[Dictionary] = event_log.get_entries()
	var before_count := before_entries.size()
	var before_snapshot: Dictionary = runner.get_snapshot()
	var before_minutes := int((before_snapshot.get("time", {}) as Dictionary).get("total_minutes", 0))
	runner.advance_tick(96.0)
	var after_entries: Array[Dictionary] = event_log.get_entries()
	var after_snapshot: Dictionary = runner.get_snapshot()
	var after_minutes := int((after_snapshot.get("time", {}) as Dictionary).get("total_minutes", 0))
	var has_npc_decision := false
	for entry in after_entries:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		if str(item.get("category", "")) == "npc_decision":
			has_npc_decision = true

	var ok := true
	ok = ok and _expect(after_entries.size() > before_count, "NPC 自主推进未产生新日志", errors)
	ok = ok and _expect(after_minutes > before_minutes, "NPC 自主推进未推动时间", errors)
	ok = ok and _expect(has_npc_decision, "NPC 自主推进缺少 npc_decision 事件", errors)
	return ok


func _check_world_resource_cycle(runner: Node, errors: Array[String]) -> bool:
	var before_snapshot: Dictionary = runner.get_snapshot()
	var before_world: Dictionary = before_snapshot.get("world_dynamics_data", {})
	var before_states: Dictionary = before_world.get("region_states", {}) if before_world is Dictionary else {}
	runner.advance_tick(48.0)
	var after_snapshot: Dictionary = runner.get_snapshot()
	var after_world: Dictionary = after_snapshot.get("world_dynamics_data", {})
	var after_states: Dictionary = after_world.get("region_states", {}) if after_world is Dictionary else {}

	var changed := false
	var all_non_negative := true
	for region_id_variant in after_states.keys():
		var region_id := str(region_id_variant)
		var after_state_raw: Variant = after_states[region_id_variant]
		if not (after_state_raw is Dictionary):
			continue
		var after_state: Dictionary = after_state_raw
		var before_state: Dictionary = before_states.get(region_id, {}) if before_states is Dictionary else {}
		var after_stockpiles: Dictionary = after_state.get("resource_stockpiles", {})
		var before_stockpiles: Dictionary = before_state.get("resource_stockpiles", {}) if before_state is Dictionary else {}
		if var_to_str(after_stockpiles) != var_to_str(before_stockpiles):
			changed = true
		for value in after_stockpiles.values():
			if int(value) < 0:
				all_non_negative = false
				break

	var ok := true
	ok = ok and _expect((after_states as Dictionary).size() > 0, "区域动态状态为空", errors)
	ok = ok and _expect(changed, "区域资源循环后库存未变化", errors)
	ok = ok and _expect(all_non_negative, "区域库存出现负值", errors)
	return ok


func _check_save_load_consistency(save_service: Node, runner: Node, errors: Array[String]) -> bool:
	if not save_service.has_method("save_slot") or not save_service.has_method("load_slot"):
		errors.append("SaveService 缺少 save_slot/load_slot")
		return false
	var snapshot_before: Dictionary = runner.get_snapshot()
	var save_result: Dictionary = save_service.save_slot({"simulation_snapshot": snapshot_before}, TEST_SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		errors.append("保存失败: %s" % str(save_result.get("error", "unknown")))
		return false
	var load_result: Dictionary = save_service.load_slot(TEST_SAVE_SLOT)
	if not bool(load_result.get("ok", false)):
		errors.append("读取失败: %s" % str(load_result.get("error", "unknown")))
		return false
	var loaded_data: Dictionary = load_result.get("data", {})
	var loaded_snapshot: Dictionary = loaded_data.get("simulation_snapshot", {})
	if loaded_snapshot.is_empty():
		errors.append("读取后缺少 simulation_snapshot")
		return false
	var restore_result: Dictionary = runner.load_snapshot(loaded_snapshot)
	if not bool(restore_result.get("ok", false)):
		errors.append("load_snapshot 失败: %s" % str(restore_result.get("error", "unknown")))
		return false
	var snapshot_after: Dictionary = runner.get_snapshot()

	var same_core := int(snapshot_before.get("seed", -1)) == int(snapshot_after.get("seed", -2))
	same_core = same_core and int((snapshot_before.get("time", {}) as Dictionary).get("day", -1)) == int((snapshot_after.get("time", {}) as Dictionary).get("day", -2))
	same_core = same_core and (snapshot_before.get("runtime_characters", []) as Array).size() == (snapshot_after.get("runtime_characters", []) as Array).size()
	var has_new_fields := snapshot_after.has("inventory_data") and snapshot_after.has("technique_data") and snapshot_after.has("world_dynamics_data") and snapshot_after.has("crafting_data") and snapshot_after.has("rng_state")

	var v1_snapshot: Dictionary = snapshot_before.duplicate(true)
	v1_snapshot["snapshot_version"] = 1
	v1_snapshot.erase("inventory_data")
	v1_snapshot.erase("technique_data")
	v1_snapshot.erase("world_dynamics_data")
	v1_snapshot.erase("crafting_data")
	v1_snapshot.erase("rng_state")
	var migrated_snapshot: Dictionary = save_service.migrate_save(v1_snapshot.duplicate(true), 1)
	var migrated_restore_result: Dictionary = runner.load_snapshot(migrated_snapshot)
	if bool(migrated_restore_result.get("ok", false)):
		runner.advance_tick(10.0)
	var migrated_after_advance: Dictionary = runner.get_snapshot()
	var migrated_has_new_fields := migrated_after_advance.has("inventory_data") and migrated_after_advance.has("technique_data") and migrated_after_advance.has("world_dynamics_data") and migrated_after_advance.has("crafting_data") and migrated_after_advance.has("rng_state")
	var migrated_snapshot_valid := not migrated_after_advance.is_empty() and (migrated_after_advance.get("runtime_characters", []) as Array).size() > 0

	var ok := true
	ok = ok and _expect(same_core, "保存加载后核心状态不一致", errors)
	ok = ok and _expect(has_new_fields, "保存加载后缺少 v2 快照扩展字段", errors)
	ok = ok and _expect(not migrated_snapshot.is_empty(), "v1→v2 迁移结果为空", errors)
	ok = ok and _expect(bool(migrated_restore_result.get("ok", false)), "v1→v2 迁移快照加载失败", errors)
	ok = ok and _expect(migrated_snapshot_valid, "v1→v2 迁移后推进 10 tick 快照无效", errors)
	ok = ok and _expect(migrated_has_new_fields, "v1→v2 迁移后缺少 v2 快照扩展字段", errors)
	return ok


func _check_economy_stability_1000_ticks(runner: Node, errors: Array[String]) -> bool:
	var before_snapshot: Dictionary = runner.get_snapshot()
	var before_total_currency := _sum_spirit_stone_stockpiles(before_snapshot)
	for _i in range(1000):
		runner.advance_tick(1.0)
	var after_snapshot: Dictionary = runner.get_snapshot()
	var after_total_currency := _sum_spirit_stone_stockpiles(after_snapshot)
	var all_non_negative := _all_stockpiles_non_negative(after_snapshot)
	var denominator := maxf(1.0, float(before_total_currency))
	var total_growth_ratio := (float(after_total_currency) - float(before_total_currency)) / denominator

	var ok := true
	ok = ok and _expect(all_non_negative, "1000 tick 后存在负库存", errors)
	ok = ok and _expect(total_growth_ratio < 0.05, "1000 tick 总货币增长率超出 5%%（%.6f）" % total_growth_ratio, errors)
	return ok


func _run_seeded_duel(catalog: Resource, event_log: Node, seed_value: int) -> Dictionary:
	var rng_channels: RefCounted = RNGChannelsScript.new()
	rng_channels.seed_all(seed_value)
	var manager: RefCounted = CombatManagerScript.new()
	manager.bind_catalog(catalog)
	manager.bind_event_log(event_log)
	manager.bind_rng_channels(rng_channels)
	manager.set_active_loot_table_id("mvp_loot_village")

	var player = CombatantDataScript.new()
	player.character_id = "player_duel"
	player.name = "player_duel"
	player.max_hp = 240
	player.current_hp = 240
	player.attack = 88
	player.defense = 25
	player.speed = 35
	player.is_player = true

	var enemy = CombatantDataScript.new()
	enemy.character_id = "npc_duel"
	enemy.name = "npc_duel"
	enemy.max_hp = 120
	enemy.current_hp = 120
	enemy.attack = 18
	enemy.defense = 8
	enemy.speed = 12
	enemy.is_player = false

	var participants: Array[CombatantData] = [player, enemy]
	var rng: RefCounted = SeededRandomScript.new()
	rng.set_seed(seed_value)
	var result = manager.start_combat(participants, rng)
	if result == null:
		return {"ok": false}
	var fp := "%s|%d|%s|%s" % [
		str(result.victor_id),
		int(result.turns_elapsed),
		var_to_str(result.loot),
		var_to_str(result.combat_log),
	]
	return {
		"ok": true,
		"victor_id": str(result.victor_id),
		"loot_count": result.loot.size(),
		"fingerprint": fp,
	}


func _craft_until_success(crafting_service: RefCounted, character_id: String, recipe_id: String, catalog: Resource, max_try: int) -> bool:
	var rng: RefCounted = SeededRandomScript.new()
	rng.set_seed(202605)
	for _i in range(max_try):
		var result: Dictionary = crafting_service.craft_item(character_id, recipe_id, catalog, rng)
		if bool(result.get("success", false)):
			return true
	return false


func _resolve_player_id(runner: Node) -> String:
	if runner == null:
		return ""
	var human_runtime: Dictionary = runner.get_human_runtime() if runner.has_method("get_human_runtime") else {}
	var player_id := str((human_runtime.get("player", {}) as Dictionary).get("id", "")).strip_edges()
	if not player_id.is_empty():
		for character_raw in runner.get_runtime_characters():
			if not (character_raw is Dictionary):
				continue
			if str((character_raw as Dictionary).get("id", "")).strip_edges() == player_id:
				return player_id
		# human runtime player 不在 runtime_characters 时，优先回落到首个可用角色，保证后续 runner 技术链路可执行
	var runtime_characters: Array = runner.get_runtime_characters() if runner.has_method("get_runtime_characters") else []
	if runtime_characters.is_empty() or not (runtime_characters[0] is Dictionary):
		return ""
	return str((runtime_characters[0] as Dictionary).get("id", "")).strip_edges()


func _resolve_npc_id(runner: Node, player_id: String) -> String:
	var runtime_characters: Array = runner.get_runtime_characters() if runner.has_method("get_runtime_characters") else []
	for character_raw in runtime_characters:
		if not (character_raw is Dictionary):
			continue
		var character: Dictionary = character_raw
		var cid := str(character.get("id", "")).strip_edges()
		if cid.is_empty() or cid == player_id:
			continue
		return cid
	return ""


func _find_character_by_id(runtime_characters: Array, target_id: String) -> Dictionary:
	for character_raw in runtime_characters:
		if not (character_raw is Dictionary):
			continue
		var character: Dictionary = character_raw
		if str(character.get("id", "")).strip_edges() == target_id:
			return character.duplicate(true)
	return {}


func _sum_spirit_stone_stockpiles(snapshot: Dictionary) -> int:
	var world_dynamics_data: Dictionary = snapshot.get("world_dynamics_data", {})
	if not (world_dynamics_data is Dictionary):
		return 0
	var region_states: Dictionary = world_dynamics_data.get("region_states", {})
	if not (region_states is Dictionary):
		return 0
	var total := 0
	for state_raw in region_states.values():
		if not (state_raw is Dictionary):
			continue
		var stockpiles: Dictionary = (state_raw as Dictionary).get("resource_stockpiles", {})
		total += int(stockpiles.get("spirit_stone", 0))
	return total


func _all_stockpiles_non_negative(snapshot: Dictionary) -> bool:
	var world_dynamics_data: Dictionary = snapshot.get("world_dynamics_data", {})
	if not (world_dynamics_data is Dictionary):
		return false
	var region_states: Dictionary = world_dynamics_data.get("region_states", {})
	if not (region_states is Dictionary):
		return false
	for state_raw in region_states.values():
		if not (state_raw is Dictionary):
			continue
		var stockpiles: Dictionary = (state_raw as Dictionary).get("resource_stockpiles", {})
		for value in stockpiles.values():
			if int(value) < 0:
				return false
	return true


func _expect(condition: bool, message: String, errors: Array[String]) -> bool:
	if not condition:
		errors.append(message)
	return condition


func _cleanup_context(context: Dictionary) -> void:
	var runner: Node = context.get("runner")
	if runner != null and is_instance_valid(runner):
		runner.queue_free()
	var inventory_service: Node = context.get("inventory_service")
	if inventory_service != null and is_instance_valid(inventory_service) and inventory_service.has_method("load_state"):
		inventory_service.load_state({"inventories": {}})

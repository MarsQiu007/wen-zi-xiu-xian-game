extends RefCounted
class_name E2EAcceptance

const CharacterCreationParamsScript = preload("res://scripts/data/character_creation_params.gd")
const WorldSeedDataScript = preload("res://scripts/data/world_seed_data.gd")
const WorldGeneratorScript = preload("res://scripts/world/world_generator.gd")
const SimulationRunnerScript = preload("res://scripts/sim/simulation_runner.gd")
const TimeServiceScript = preload("res://autoload/time_service.gd")
const EventLogScript = preload("res://autoload/event_log.gd")
const RunStateScript = preload("res://autoload/run_state.gd")
const LocationServiceScript = preload("res://autoload/location_service.gd")
const NpcBehaviorLibraryScript = preload("res://scripts/npc/npc_behavior_library.gd")
const NpcDecisionEngineScript = preload("res://scripts/npc/npc_decision_engine.gd")
const RelationshipNetworkScript = preload("res://scripts/npc/relationship_network.gd")
const NpcMemorySystemScript = preload("res://scripts/npc/npc_memory_system.gd")

const REPORT_PATH := ".sisyphus/evidence/task-19-e2e-report.txt"


class _SeedDataAdapter:
	extends Resource

	var seed_value: int = 0
	var region_count: int = 7
	var npc_count: int = 30
	var resource_density: float = 0.5
	var monster_density: float = 0.3


func execute(scene_tree: SceneTree) -> Variant:
	return run_all_tests()


func test_full_flow() -> Dictionary:
	var errors: Array[String] = []
	var checks: Dictionary = {}

	var run_state := RunStateScript.new()
	run_state.set_mode(&"human")
	run_state.set_phase(&"mode_select")
	checks["phase_mode_select"] = _expect_true(run_state.phase == &"mode_select", "RunState 未进入 mode_select", errors)
	run_state.set_phase(&"char_creation")
	checks["phase_char_creation"] = _expect_true(run_state.phase == &"char_creation", "RunState 未进入 char_creation", errors)
	run_state.set_phase(&"world_init")
	checks["phase_world_init"] = _expect_true(run_state.phase == &"world_init", "RunState 未进入 world_init", errors)
	run_state.set_phase(&"main_play")
	checks["phase_main_play"] = _expect_true(run_state.phase == &"main_play", "RunState 未进入 main_play", errors)

	var creation_params = CharacterCreationParamsScript.new()
	creation_params.character_name = "验收主角"
	creation_params.morality_value = 12.5
	creation_params.birth_region_id = &"region_0"
	creation_params.opening_type = &"youth"
	creation_params.difficulty = 2
	creation_params.custom_seed = 12345
	var creation_dict: Dictionary = creation_params.to_dict()
	var creation_restored = CharacterCreationParamsScript.from_dict(creation_dict)
	checks["creation_serialization"] = _expect_true(
		creation_restored.character_name == creation_params.character_name
			and is_equal_approx(creation_restored.morality_value, creation_params.morality_value)
			and creation_restored.birth_region_id == creation_params.birth_region_id
			and creation_restored.opening_type == creation_params.opening_type
			and creation_restored.difficulty == creation_params.difficulty
			and creation_restored.custom_seed == creation_params.custom_seed,
		"CharacterCreationParams 序列化/反序列化不一致",
		errors
	)

	var seed_data = WorldSeedDataScript.new()
	seed_data.seed_value = 12345
	seed_data.region_count = 7
	seed_data.npc_count = 30
	seed_data.resource_density = 0.5
	seed_data.monster_density = 0.3
	var seed_dict: Dictionary = seed_data.to_dict()
	var seed_restored = WorldSeedDataScript.from_dict(seed_dict)
	checks["seed_serialization"] = _expect_true(
		seed_restored.seed_value == seed_data.seed_value
			and seed_restored.region_count == seed_data.region_count
			and seed_restored.npc_count == seed_data.npc_count
			and is_equal_approx(seed_restored.resource_density, seed_data.resource_density)
			and is_equal_approx(seed_restored.monster_density, seed_data.monster_density),
		"WorldSeedData 序列化/反序列化不一致",
		errors
	)

	var generator = WorldGeneratorScript.new()
	var world_data: Dictionary = generator.generate(_make_seed_resource(seed_data.seed_value, seed_data.region_count, seed_data.npc_count, seed_data.resource_density, seed_data.monster_density))
	checks["world_generation_called"] = _expect_true(not world_data.is_empty(), "WorldGenerator.generate() 返回空数据", errors)
	checks["world_has_characters"] = _expect_true((world_data.get("characters", []) as Array).size() > 0, "生成世界缺少 characters", errors)
	checks["world_has_relationships"] = _expect_true((world_data.get("relationships", []) as Array).size() > 0, "生成世界缺少 relationships", errors)
	checks["world_has_regions"] = _expect_true((world_data.get("regions", []) as Array).size() > 0, "生成世界缺少 regions", errors)

	var runner_pack := _create_runner(creation_dict, seed_dict)
	if not bool(runner_pack.get("ok", false)):
		errors.append("SimulationRunner 初始化失败")
		return _result("test_full_flow", false, checks, errors)

	var runner: Node = runner_pack.get("runner")
	var time_service: Node = runner_pack.get("time_service")
	checks["bootstrap_from_creation"] = _expect_true((runner.get_runtime_characters() as Array).size() > 0, "bootstrap_from_creation 后无运行时角色", errors)

	var before_manual_hours := float(time_service.total_hours)
	time_service.advance_hours(2.0)
	checks["time_service_advance_hours"] = _expect_true(float(time_service.total_hours) > before_manual_hours, "TimeService.advance_hours 未推进时间", errors)

	var before_tick_hours := float(time_service.total_hours)
	runner.advance_tick(1.0)
	checks["runner_advance_tick"] = _expect_true(float(time_service.total_hours) > before_tick_hours, "SimulationRunner.advance_tick 未推进时间", errors)

	var ui_result := _test_ui_tab_switching()
	checks["ui_tab_switch"] = bool(ui_result.get("ok", false))
	if not checks["ui_tab_switch"]:
		errors.append(str(ui_result.get("error", "UI 标签页切换失败")))

	_cleanup_runner(runner_pack)
	run_state.free()
	return _result("test_full_flow", errors.is_empty(), checks, errors)


func test_time_speed() -> Dictionary:
	var errors: Array[String] = []
	var checks: Dictionary = {}
	var time_service := TimeServiceScript.new()

	time_service.set_speed_tier(1)
	checks["tier_1"] = _expect_true(is_equal_approx(float(time_service.get_hours_per_tick()), 0.5), "speed_tier=1 时 hours_per_tick 不是 0.5", errors)

	time_service.set_speed_tier(2)
	checks["tier_2"] = _expect_true(is_equal_approx(float(time_service.get_hours_per_tick()), 1.0), "speed_tier=2 时 hours_per_tick 不是 1.0", errors)

	time_service.set_speed_tier(3)
	checks["tier_3"] = _expect_true(is_equal_approx(float(time_service.get_hours_per_tick()), 24.0), "speed_tier=3 时 hours_per_tick 不是 24.0", errors)

	time_service.set_speed_tier(4)
	checks["tier_4"] = _expect_true(is_equal_approx(float(time_service.get_hours_per_tick()), 720.0), "speed_tier=4 时 hours_per_tick 不是 720.0", errors)

	time_service.set_speed_tier(0)
	checks["clamp_low"] = _expect_true(int(time_service.speed_tier) == 1 and is_equal_approx(float(time_service.get_hours_per_tick()), 0.5), "speed_tier 下界 clamp 失败", errors)

	time_service.set_speed_tier(99)
	checks["clamp_high"] = _expect_true(int(time_service.speed_tier) == 4 and is_equal_approx(float(time_service.get_hours_per_tick()), 720.0), "speed_tier 上界 clamp 失败", errors)

	time_service.free()
	return _result("test_time_speed", errors.is_empty(), checks, errors)


func test_npc_behavior() -> Dictionary:
	var errors: Array[String] = []
	var checks: Dictionary = {}

	var behavior_library = NpcBehaviorLibraryScript.new()
	var behavior_count: int = behavior_library.BEHAVIOR_DEFS.size()
	checks["behavior_count"] = _expect_true(behavior_count >= 40, "NpcBehaviorLibrary 行为定义少于 40", errors)

	var social_behaviors: Array = behavior_library.get_behaviors_by_category(&"social")
	var category_ok := social_behaviors.size() > 0
	for behavior in social_behaviors:
		if behavior.category != &"social":
			category_ok = false
			break
	checks["category_query"] = _expect_true(category_ok, "get_behaviors_by_category 返回类别不正确", errors)

	var engine = NpcDecisionEngineScript.new()
	var relationship_network = RelationshipNetworkScript.new()
	var memory_system = NpcMemorySystemScript.new()
	var npc_state := {
		"id": &"npc_e2e",
		"npc_id": &"npc_e2e",
		"realm": &"mortal",
		"realm_progress": 10.0,
		"has_technique": false,
		"pressures": {
			"survival": 8,
			"family": 6,
			"learning": 5,
			"cultivation": 4,
		},
		"morality": 0.0,
		"life_stage": &"young_adult",
		"last_action_hours": {},
	}
	var decision: Dictionary = engine.decide_action(npc_state, {
		"current_hours": 0.0,
		"relationships": relationship_network,
		"memory_system": memory_system,
	})
	checks["decision_engine"] = _expect_true(
		decision.has("action")
			and decision.get("action") != null
			and str(decision.get("reason", "")).length() > 0
			and str(decision.get("reason", "")) != "no_available_behavior",
		"NpcDecisionEngine 未能产出有效决策",
		errors
	)
	checks["decision_interval"] = _expect_true(float(engine.get_decision_interval(npc_state)) > 0.0, "NpcDecisionEngine 决策间隔无效", errors)

	return _result("test_npc_behavior", errors.is_empty(), checks, errors)


func test_save_load_consistency() -> Dictionary:
	var errors: Array[String] = []
	var checks: Dictionary = {}

	var creation_dict := {
		"snapshot_version": 1,
		"character_name": "存档验收主角",
		"morality_value": 5.0,
		"birth_region_id": "region_0",
		"opening_type": "youth",
		"difficulty": 1,
		"custom_seed": 45678,
	}
	var seed_dict := {
		"snapshot_version": 1,
		"seed_value": 45678,
		"region_count": 7,
		"npc_count": 30,
		"resource_density": 0.5,
		"monster_density": 0.3,
	}

	var runner_pack := _create_runner(creation_dict, seed_dict)
	if not bool(runner_pack.get("ok", false)):
		errors.append("SimulationRunner 初始化失败")
		return _result("test_save_load_consistency", false, checks, errors)

	var runner: Node = runner_pack.get("runner")
	runner.advance_tick(24.0)
	var snapshot: Dictionary = runner.get_snapshot()

	checks["snapshot_creation_params"] = _expect_true(snapshot.has("creation_params"), "snapshot 缺少 creation_params", errors)
	checks["snapshot_world_seed"] = _expect_true(snapshot.has("world_seed"), "snapshot 缺少 world_seed", errors)
	checks["snapshot_relationship_network"] = _expect_true(snapshot.has("relationship_network"), "snapshot 缺少 relationship_network", errors)
	checks["snapshot_memory_system"] = _expect_true(snapshot.has("memory_system"), "snapshot 缺少 memory_system", errors)
	checks["snapshot_speed_tier"] = _expect_true(snapshot.has("speed_tier"), "snapshot 缺少 speed_tier", errors)

	var before_time_day := int((snapshot.get("time", {}) as Dictionary).get("day", -1))
	var before_seed := int(snapshot.get("seed", -1))
	var before_speed_tier := int(snapshot.get("speed_tier", -1))
	var before_creation: Dictionary = (snapshot.get("creation_params", {}) as Dictionary).duplicate(true)
	var before_world_seed: Dictionary = (snapshot.get("world_seed", {}) as Dictionary).duplicate(true)
	var before_character_count := (snapshot.get("runtime_characters", []) as Array).size()
	var before_edge_count := ((snapshot.get("relationship_network", {}) as Dictionary).get("edges", []) as Array).size()

	var load_result: Dictionary = runner.load_snapshot(snapshot)
	checks["load_snapshot_ok"] = _expect_true(bool(load_result.get("ok", false)), "load_snapshot 返回失败", errors)

	var restored: Dictionary = runner.get_snapshot()
	checks["restored_seed"] = _expect_true(int(restored.get("seed", -2)) == before_seed, "恢复后 seed 不一致", errors)
	checks["restored_speed_tier"] = _expect_true(int(restored.get("speed_tier", -2)) == before_speed_tier, "恢复后 speed_tier 不一致", errors)
	checks["restored_time_day"] = _expect_true(int((restored.get("time", {}) as Dictionary).get("day", -2)) == before_time_day, "恢复后 time.day 不一致", errors)
	checks["restored_creation_params"] = _expect_true((restored.get("creation_params", {}) as Dictionary) == before_creation, "恢复后 creation_params 不一致", errors)
	checks["restored_world_seed"] = _expect_true((restored.get("world_seed", {}) as Dictionary) == before_world_seed, "恢复后 world_seed 不一致", errors)
	checks["restored_character_count"] = _expect_true((restored.get("runtime_characters", []) as Array).size() == before_character_count, "恢复后 runtime_characters 数量不一致", errors)
	checks["restored_relationship_count"] = _expect_true((((restored.get("relationship_network", {}) as Dictionary).get("edges", []) as Array).size() == before_edge_count), "恢复后 relationship_network 数量不一致", errors)

	_cleanup_runner(runner_pack)
	return _result("test_save_load_consistency", errors.is_empty(), checks, errors)


func test_seed_diversity() -> Dictionary:
	var errors: Array[String] = []
	var checks: Dictionary = {}

	var generator = WorldGeneratorScript.new()
	var seed_a = WorldSeedDataScript.new()
	seed_a.seed_value = 111
	seed_a.region_count = 7
	seed_a.npc_count = 30
	var world_a: Dictionary = generator.generate(_make_seed_resource(seed_a.seed_value, seed_a.region_count, seed_a.npc_count, seed_a.resource_density, seed_a.monster_density))

	var seed_b = WorldSeedDataScript.new()
	seed_b.seed_value = 222
	seed_b.region_count = 7
	seed_b.npc_count = 30
	var world_b: Dictionary = generator.generate(_make_seed_resource(seed_b.seed_value, seed_b.region_count, seed_b.npc_count, seed_b.resource_density, seed_b.monster_density))

	var set_a := _build_npc_identity_set(world_a)
	var set_b := _build_npc_identity_set(world_b)
	var diff_rate := _set_difference_rate(set_a, set_b)

	checks["non_empty_sets"] = _expect_true((set_a.size() > 0 and set_b.size() > 0), "seed 世界 NPC 集合为空", errors)
	checks["diff_rate_gt_0_5"] = _expect_true(diff_rate > 0.5, "不同 seed 世界差异率不大于 0.5", errors)

	return {
		"name": "test_seed_diversity",
		"ok": errors.is_empty(),
		"checks": checks,
		"errors": errors,
		"metrics": {
			"set_a_size": set_a.size(),
			"set_b_size": set_b.size(),
			"difference_rate": diff_rate,
		},
	}


func run_all_tests() -> Dictionary:
	var start_usec := Time.get_ticks_usec()
	var tests: Array[Dictionary] = [
		test_full_flow(),
		test_time_speed(),
		test_npc_behavior(),
		test_save_load_consistency(),
		test_seed_diversity(),
	]

	var passed := 0
	for test_result in tests:
		if bool(test_result.get("ok", false)):
			passed += 1

	var report := {
		"task": "T19",
		"suite": "e2e_acceptance",
		"overall_ok": passed == tests.size(),
		"passed": passed,
		"total": tests.size(),
		"duration_ms": float(Time.get_ticks_usec() - start_usec) / 1000.0,
		"tests": tests,
		"generated_at_unix": int(Time.get_unix_time_from_system()),
	}

	_write_report(report)
	return report


func _create_runner(creation_dict: Dictionary, seed_dict: Dictionary) -> Dictionary:
	var time_service: Node = TimeServiceScript.new()
	var event_log: Node = EventLogScript.new()
	var run_state: Node = RunStateScript.new()
	var location_service: Node = LocationServiceScript.new()
	var runner: Node = SimulationRunnerScript.new()

	runner.setup_services(time_service, event_log, run_state, location_service)
	runner.bootstrap_from_creation(creation_dict, seed_dict)
	return {
		"ok": true,
		"runner": runner,
		"time_service": time_service,
		"event_log": event_log,
		"run_state": run_state,
		"location_service": location_service,
	}


func _cleanup_runner(runner_pack: Dictionary) -> void:
	var runner: Node = runner_pack.get("runner")
	if runner != null:
		runner.free()
	for key in ["location_service", "run_state", "event_log", "time_service"]:
		var node: Node = runner_pack.get(key)
		if node != null:
			node.free()


func _test_ui_tab_switching() -> Dictionary:
	var ui_root = load("res://scripts/ui/ui_root.gd").new()
	if ui_root == null:
		return {"ok": false, "error": "无法创建 UIRoot 实例"}

	var log_panel := PanelContainer.new()
	var map_panel := PanelContainer.new()
	var world_chars_panel := PanelContainer.new()
	var favor_panel := PanelContainer.new()
	var inventory_panel := PanelContainer.new()

	ui_root.set("_log_content_panel", log_panel)
	ui_root.set("_map_content_panel", map_panel)
	ui_root.set("_world_chars_panel", world_chars_panel)
	ui_root.set("_favor_panel", favor_panel)
	ui_root.set("_inventory_panel", inventory_panel)

	var tab_map := {
		"log": log_panel,
		"map": map_panel,
		"world_chars": world_chars_panel,
		"favor": favor_panel,
		"inventory": inventory_panel,
	}
	for tab in tab_map.keys():
		ui_root.set("_active_tab", tab)
		ui_root.call("_update_right_content_visibility")
		for probe_tab in tab_map.keys():
			var panel: PanelContainer = tab_map[probe_tab]
			var should_visible: bool = probe_tab == tab
			if panel.visible != should_visible:
				return {"ok": false, "error": "标签页 %s 显示状态异常（检测 %s）" % [tab, probe_tab]}

	return {"ok": true}


func _build_npc_identity_set(world_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for npc_variant in world_data.get("characters", []):
		if not (npc_variant is Dictionary):
			continue
		var npc: Dictionary = npc_variant
		var identity := "%s|%s|%s" % [
			str(npc.get("id", "")),
			str(npc.get("display_name", "")),
			str(npc.get("birth_region_id", "")),
		]
		if identity.is_empty():
			continue
		result[identity] = true
	return result


func _make_seed_resource(seed_value: int, region_count: int = 7, npc_count: int = 30, resource_density: float = 0.5, monster_density: float = 0.3) -> Resource:
	var seed_resource := _SeedDataAdapter.new()
	seed_resource.seed_value = seed_value
	seed_resource.region_count = region_count
	seed_resource.npc_count = npc_count
	seed_resource.resource_density = resource_density
	seed_resource.monster_density = monster_density
	return seed_resource


func _set_difference_rate(set_a: Dictionary, set_b: Dictionary) -> float:
	var union_count := 0
	var diff_count := 0
	var seen: Dictionary = {}
	for key in set_a.keys():
		seen[key] = true
	for key in set_b.keys():
		seen[key] = true

	for key in seen.keys():
		union_count += 1
		var in_a := bool(set_a.get(key, false))
		var in_b := bool(set_b.get(key, false))
		if in_a and not in_b:
			diff_count += 1

	if union_count <= 0:
		return 0.0
	return float(diff_count) / float(union_count)


func _result(test_name: String, ok: bool, checks: Dictionary, errors: Array[String]) -> Dictionary:
	return {
		"name": test_name,
		"ok": ok,
		"checks": checks,
		"errors": errors,
	}


func _expect_true(condition: bool, message: String, errors: Array[String]) -> bool:
	if not condition:
		errors.append(message)
	return condition


func _write_report(report: Dictionary) -> void:
	var evidence_dir_abs := ProjectSettings.globalize_path("res://.sisyphus/evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir_abs)
	var report_abs := ProjectSettings.globalize_path("res://" + REPORT_PATH)
	var file := FileAccess.open(report_abs, FileAccess.WRITE)
	if file == null:
		return

	file.store_string("=== Task 19 E2E 验收报告 ===\n")
	file.store_string("overall_ok=%s\n" % str(report.get("overall_ok", false)))
	file.store_string("passed=%s/%s\n" % [str(report.get("passed", 0)), str(report.get("total", 0))])
	file.store_string("duration_ms=%s\n\n" % str(report.get("duration_ms", 0.0)))

	for test_result in report.get("tests", []):
		var test_name := str(test_result.get("name", "unknown"))
		file.store_string("[%s]\n" % test_name)
		file.store_string("ok=%s\n" % str(test_result.get("ok", false)))
		file.store_string("checks=%s\n" % JSON.stringify(test_result.get("checks", {})))
		file.store_string("errors=%s\n" % JSON.stringify(test_result.get("errors", [])))
		if test_result.has("metrics"):
			file.store_string("metrics=%s\n" % JSON.stringify(test_result.get("metrics", {})))
		file.store_string("\n")

	file.flush()
	file.close()

extends RefCounted
class_name Task9Smoke

const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")
const VILLAGE_HEIR_PATH := "res://resources/world/samples/mvp_character_village_heir.tres"
const DIVINE_VISIONARY_PATH := "res://resources/world/samples/mvp_character_divine_visionary.tres"


func run(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, _scenario: String, seed: int, _days: int) -> Dictionary:
	print("SMOKE_START|task=task9|scenario=minimal_closure|seed=%d" % seed)
	var relation_case := _run_relation_case(scene_root, time_service, run_state, event_log, seed)
	if bool(relation_case.get("failed", false)):
		return relation_case
	var direct_line_case := _run_direct_line_case(scene_root, time_service, run_state, event_log, seed)
	if bool(direct_line_case.get("failed", false)):
		return direct_line_case
	var legal_heir_case := _run_legal_heir_case(scene_root, time_service, run_state, event_log, seed)
	if bool(legal_heir_case.get("failed", false)):
		return legal_heir_case
	var no_heir_case := _run_no_heir_case(scene_root, time_service, run_state, event_log, seed)
	if bool(no_heir_case.get("failed", false)):
		return no_heir_case
	return {
		"failed": false,
		"message": "task9 最小闭环验证通过",
	}


func _run_relation_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	var village_heir: Resource = load(VILLAGE_HEIR_PATH)
	var visionary: Resource = load(DIVINE_VISIONARY_PATH)
	if village_heir == null or visionary == null:
		return {
			"failed": true,
			"message": "task9 关系样例资源加载失败",
		}
	var marriage_id := str(village_heir.get("spouse_character_id"))
	var dao_id := str(visionary.get("dao_companion_character_id"))
	var distinct := not marriage_id.is_empty() and not dao_id.is_empty() and marriage_id != dao_id
	print("ASSERT|scenario=task9_relations|marriage_id=%s|dao_companion_id=%s|distinct=%s" % [marriage_id, dao_id, str(distinct)])
	return {
		"failed": not distinct,
		"message": "婚姻与道侣关系未能区分",
	}


func _run_direct_line_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	var outcome := _run_case(scene_root, time_service, run_state, event_log, seed, 2, {
		"player_id": "task9_founder_direct",
		"player_name": "林守成",
		"family_id": "mvp_lin_family",
		"spouse_character_id": "task9_spouse",
		"dao_companion_character_id": "task9_dao_guardian",
		"direct_line_child_ids": ["task9_direct_child", "task9_younger_child"],
		"legal_heir_character_id": "task9_legal_heir",
		"forced_death_day": 1,
		"runtime_characters": [
			{
				"id": "task9_direct_child",
				"display_name": "林承序",
				"family_id": "mvp_lin_family",
				"inheritance_priority": 1,
			},
			{
				"id": "task9_younger_child",
				"display_name": "林承让",
				"family_id": "mvp_lin_family",
				"inheritance_priority": 3,
			},
			{
				"id": "task9_legal_heir",
				"display_name": "林立契",
				"family_id": "mvp_lin_family",
				"inheritance_priority": 0,
			}
		],
	})
	if bool(outcome.get("failed", false)):
		return outcome
	var runtime: Dictionary = outcome.get("runtime", {})
	var last_death: Dictionary = runtime.get("lineage", {}).get("last_death", {})
	var current_player: Dictionary = runtime.get("player", {})
	var direct_line_won := str(last_death.get("heir_id", "")) == "task9_direct_child"
	var switched := str(current_player.get("id", "")) == "task9_direct_child"
	var reason_ok := str(last_death.get("reason", "")) == "direct_line_descendant"
	print("ASSERT|scenario=task9_direct_line|heir_id=%s|current_player=%s|reason=%s|used_direct_line=%s|used_legal_heir=%s" % [
		str(last_death.get("heir_id", "")),
		str(current_player.get("id", "")),
		str(last_death.get("reason", "")),
		str(last_death.get("used_direct_line", false)),
		str(last_death.get("used_legal_heir", false)),
	])
	return {
		"failed": not (direct_line_won and switched and reason_ok),
		"message": "直系继承未压过法定继承人",
	}


func _run_legal_heir_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	var outcome := _run_case(scene_root, time_service, run_state, event_log, seed + 1, 2, {
		"player_id": "task9_founder_legal",
		"player_name": "沈问礼",
		"family_id": "mvp_shen_family",
		"spouse_character_id": "task9_legal_spouse",
		"dao_companion_character_id": "task9_legal_dao",
		"direct_line_child_ids": [],
		"legal_heir_character_id": "task9_designated_heir",
		"forced_death_day": 1,
		"runtime_characters": [
			{
				"id": "task9_designated_heir",
				"display_name": "沈执契",
				"family_id": "mvp_shen_family",
				"inheritance_priority": 2,
			}
		],
	})
	if bool(outcome.get("failed", false)):
		return outcome
	var runtime: Dictionary = outcome.get("runtime", {})
	var last_death: Dictionary = runtime.get("lineage", {}).get("last_death", {})
	var current_player: Dictionary = runtime.get("player", {})
	var legal_heir_used := str(last_death.get("heir_id", "")) == "task9_designated_heir"
	var switched := str(current_player.get("id", "")) == "task9_designated_heir"
	var reason_ok := str(last_death.get("reason", "")) == "designated_legal_heir"
	print("ASSERT|scenario=task9_legal_heir|heir_id=%s|current_player=%s|reason=%s|used_direct_line=%s|used_legal_heir=%s" % [
		str(last_death.get("heir_id", "")),
		str(current_player.get("id", "")),
		str(last_death.get("reason", "")),
		str(last_death.get("used_direct_line", false)),
		str(last_death.get("used_legal_heir", false)),
	])
	return {
		"failed": not (legal_heir_used and switched and reason_ok),
		"message": "无法在无直系时回落到法定继承人",
	}


func _run_no_heir_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	var outcome := _run_case(scene_root, time_service, run_state, event_log, seed + 2, 2, {
		"player_id": "task9_founder_none",
		"player_name": "顾行舟",
		"family_id": "mvp_lin_family",
		"spouse_character_id": "task9_none_spouse",
		"dao_companion_character_id": "task9_none_dao",
		"direct_line_child_ids": [],
		"legal_heir_character_id": "",
		"forced_death_day": 1,
	})
	if bool(outcome.get("failed", false)):
		return outcome
	var runtime: Dictionary = outcome.get("runtime", {})
	var lineage: Dictionary = runtime.get("lineage", {})
	var terminated := bool(lineage.get("terminated", false))
	var reason_ok := str(lineage.get("termination_reason", "")) == "no_heir_after_death"
	var current_player_id := str(runtime.get("current_player_id", ""))
	var found_termination_log := false
	var human_action_after_termination := false
	for entry in event_log.entries:
		if str(entry.get("category", "")) == "human_lineage" and str(entry.get("direct_cause", "")) == "human_protagonist_death":
			found_termination_log = str(entry.get("result", "")).find("平稳终止") != -1
		if str(entry.get("category", "")) == "human_action":
			human_action_after_termination = true
	print("ASSERT|scenario=task9_no_heir|terminated=%s|termination_reason=%s|current_player_id=%s|termination_log=%s" % [
		str(terminated),
		str(lineage.get("termination_reason", "")),
		current_player_id,
		str(found_termination_log),
	])
	return {
		"failed": not (terminated and reason_ok and current_player_id.is_empty() and found_termination_log and not human_action_after_termination),
		"message": "无继承人死亡未能平稳终止",
	}


func _run_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int, days: int, options: Dictionary) -> Dictionary:
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"human")
	var runner: Node = RUNNER_SCENE.instantiate()
	scene_root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state)
	runner.configure_human_mode(options)
	runner.bootstrap(seed)
	runner.advance_days(days, false, true)
	for line in event_log.get_summary_lines(20):
		print(line)
	var runtime: Dictionary = runner.get_human_runtime()
	runner.free()
	return {
		"failed": runtime.is_empty(),
		"message": "task9 运行时为空",
		"runtime": runtime,
	}

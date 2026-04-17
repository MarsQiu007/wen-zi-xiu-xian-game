extends RefCounted
class_name Task7Smoke

const TASK7_CATALOG_PATH := "res://resources/world/task7/task7_world_data_catalog.tres"
const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")

const MORALITY_ACTOR_IDS := [
	"task7_kind_collector",
	"task7_ruthless_collector",
]

const FOCUS_ACTOR_IDS := [
	"task7_focused_scribe",
	"task7_background_scribe",
]


func run(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, scenario: String, seed: int, days: int) -> Dictionary:
	var normalized_scenario := scenario.to_lower()
	var runner: Node = RUNNER_SCENE.instantiate()
	scene_root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state)
	runner.configure_catalog_path(TASK7_CATALOG_PATH)
	runner.bootstrap(seed)
	var result := {}
	match normalized_scenario:
		"morality":
			result = _run_morality_scenario(runner, event_log, seed)
		"focus":
			result = _run_focus_scenario(runner, event_log, seed, days)
		_:
			result = {
				"failed": true,
				"message": "未知 task7 场景: %s" % normalized_scenario,
			}
	runner.free()
	return result


func _run_morality_scenario(runner: Node, event_log: Node, seed: int) -> Dictionary:
	print("SMOKE_START|task=task7|scenario=morality|seed=%d" % seed)
	runner.advance_days(1, false, true)
	for line in event_log.get_summary_lines(20):
		print(line)
	var action_entries := _find_action_entries(event_log.get_entries(), MORALITY_ACTOR_IDS)
	if action_entries.size() != 2:
		return {
			"failed": true,
			"message": "morality 场景期望 2 条行动日志，实际 %d 条" % action_entries.size(),
		}
	var first_trace: Dictionary = action_entries[0].get("trace", {})
	var second_trace: Dictionary = action_entries[1].get("trace", {})
	var same_need := str(first_trace.get("need_key", "")) == str(second_trace.get("need_key", ""))
	var same_goal := str(first_trace.get("goal_id", "")) == str(second_trace.get("goal_id", ""))
	var same_intent := str(first_trace.get("intent", "")) == str(second_trace.get("intent", ""))
	var different_method := str(first_trace.get("method", "")) != str(second_trace.get("method", ""))
	var different_morality := str(first_trace.get("morality_style", "")) != str(second_trace.get("morality_style", ""))
	print("ASSERT|scenario=morality|same_need=%s|same_goal=%s|same_intent=%s|different_method=%s|different_morality=%s" % [
		str(same_need),
		str(same_goal),
		str(same_intent),
		str(different_method),
		str(different_morality),
	])
	return {
		"failed": not (same_need and same_goal and same_intent and different_method and different_morality),
		"message": "morality 场景完成",
	}


func _run_focus_scenario(runner: Node, event_log: Node, seed: int, days: int) -> Dictionary:
	var resolved_days := maxi(3, days)
	print("SMOKE_START|task=task7|scenario=focus|seed=%d|days=%d" % [seed, resolved_days])
	runner.advance_days(resolved_days, false, true)
	for line in event_log.get_summary_lines(40):
		print(line)
	var action_entries := _find_action_entries(event_log.get_entries(), FOCUS_ACTOR_IDS)
	var counts := {}
	var detail_levels := {}
	for entry in action_entries:
		var actor_id := str((entry.get("actor_ids", PackedStringArray()) as PackedStringArray)[0])
		counts[actor_id] = int(counts.get(actor_id, 0)) + 1
		var levels: PackedStringArray = detail_levels.get(actor_id, PackedStringArray())
		levels.append(str(entry.get("trace", {}).get("detail_level", "")))
		detail_levels[actor_id] = levels
	var focused_count := int(counts.get("task7_focused_scribe", 0))
	var background_count := int(counts.get("task7_background_scribe", 0))
	var focused_levels: PackedStringArray = detail_levels.get("task7_focused_scribe", PackedStringArray())
	var background_levels: PackedStringArray = detail_levels.get("task7_background_scribe", PackedStringArray())
	var focused_dense := focused_count > background_count and focused_count >= resolved_days
	var background_sparse := background_count <= int(ceili(float(resolved_days) / 2.0))
	var focused_detailed := _all_levels_match(focused_levels, "detailed")
	var background_summarized := _all_levels_match(background_levels, "summary")
	print("ASSERT|scenario=focus|focused_count=%d|background_count=%d|focused_detailed=%s|background_summarized=%s" % [
		focused_count,
		background_count,
		str(focused_detailed),
		str(background_summarized),
	])
	return {
		"failed": not (focused_dense and background_sparse and focused_detailed and background_summarized),
		"message": "focus 场景完成",
	}


func _find_action_entries(entries: Array[Dictionary], actor_ids: Array) -> Array[Dictionary]:
	var actor_lookup := {}
	for actor_id in actor_ids:
		actor_lookup[str(actor_id)] = true
	var results: Array[Dictionary] = []
	for entry in entries:
		if str(entry.get("category", "")) != "npc_action":
			continue
		var ids: PackedStringArray = entry.get("actor_ids", PackedStringArray())
		if ids.is_empty():
			continue
		if actor_lookup.has(str(ids[0])):
			results.append(entry)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str((a.get("actor_ids", PackedStringArray()) as PackedStringArray)[0]) < str((b.get("actor_ids", PackedStringArray()) as PackedStringArray)[0])
	)
	return results


func _all_levels_match(levels: PackedStringArray, expected: String) -> bool:
	if levels.is_empty():
		return false
	for level in levels:
		if str(level) != expected:
			return false
	return true

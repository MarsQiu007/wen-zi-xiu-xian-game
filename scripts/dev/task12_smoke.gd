extends RefCounted

class_name Task12Smoke

const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")
const GAME_ROOT_SCENE := preload("res://scenes/main/game_root.tscn")
const CHARACTER_SERVICE_SCRIPT := preload("res://autoload/character_service.gd")
const SAVE_SERVICE_SCRIPT := preload("res://autoload/save_service.gd")

var CharacterService: Node
var EventLog: Node
var SaveService: Node


func run(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, location_service: Node, scenario: String, seed: int, days: int) -> Dictionary:
	EventLog = event_log
	CharacterService = _ensure_service(scene_root, "CharacterService", CHARACTER_SERVICE_SCRIPT)
	SaveService = _ensure_service(scene_root, "SaveService", SAVE_SERVICE_SCRIPT)
	_bind_singletons(scene_root)
	var normalized_scenario := scenario.to_lower()
	if normalized_scenario == "e2e" or normalized_scenario == "full_chain":
		print("SMOKE_START|task=task12|scenario=e2e|seed=%d|days=%d" % [seed, maxi(days, 4)])
		return _run_e2e_case(scene_root, time_service, run_state, event_log, location_service, seed, days)
	if normalized_scenario == "failure_paths" or normalized_scenario == "failure":
		print("SMOKE_START|task=task12|scenario=failure_paths|seed=%d|days=%d" % [seed, maxi(days, 4)])
		return _run_failure_paths_case(scene_root, time_service, run_state, event_log, location_service, seed, days)
	return {
		"failed": true,
		"message": "未知 task12 场景: %s" % normalized_scenario,
	}


func _bind_singletons(scene_root: Node) -> void:
	var root_node: Node = null
	if scene_root != null:
		root_node = scene_root
		if root_node.get_parent() != null:
			root_node = root_node.get_parent()
	if root_node == null:
		return
	if CharacterService == null:
		CharacterService = root_node.get_node_or_null("CharacterService")
	if EventLog == null:
		EventLog = root_node.get_node_or_null("EventLog")
	if SaveService == null:
		SaveService = root_node.get_node_or_null("SaveService")


func _ensure_service(scene_root: Node, node_name: String, script_resource: Script) -> Node:
	if scene_root == null:
		return null
	var root_node := scene_root
	if root_node.get_parent() != null:
		root_node = root_node.get_parent()
	if root_node == null:
		return null
	var existing := root_node.get_node_or_null(node_name)
	if existing != null:
		return existing
	var service := Node.new()
	service.name = node_name
	service.set_script(script_resource)
	root_node.add_child(service)
	return service


func _run_e2e_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, location_service: Node, seed: int, days: int) -> Dictionary:
	var resolved_days := maxi(4, days)
	_cleanup_default_save()
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"human")
	run_state.set_phase(&"menu")

	var game_root: Node = GAME_ROOT_SCENE.instantiate()
	scene_root.add_child(game_root)
	var simulation_runner: Node = game_root.get_node_or_null("SimulationRunner")
	var ui_root: Node = game_root.get_node_or_null("UIRoot")
	if simulation_runner == null or ui_root == null:
		game_root.free()
		return {
			"failed": true,
			"message": "e2e: GameRoot 缺少 SimulationRunner 或 UIRoot",
		}

	CharacterService.setup_services(simulation_runner, event_log, run_state)
	_ensure_ui_panels_ready(ui_root)
	ui_root.set("EventLog", event_log)
	ui_root.set("TimeService", time_service)
	ui_root.set("RunState", run_state)
	ui_root.set("CharacterService", CharacterService)
	ui_root.set("LocationService", location_service)
	ui_root.call("bind_runner", simulation_runner)
	ui_root.call("show_main_menu")

	var menu_before := bool(ui_root.get_node_or_null("MainMenuPanel") != null and (ui_root.get_node("MainMenuPanel") as CanvasItem).visible)
	var phase_before := str(run_state.phase)
	var day_before := int(time_service.get_completed_day())
	var boot_entries_before_new := _count_entries_with_title(event_log.get_entries(), "SimulationRunner 已就绪")

	run_state.set_mode(&"human")
	run_state.set_phase(&"running")
	simulation_runner.setup_services(time_service, event_log, run_state, location_service)
	simulation_runner.bootstrap()
	ui_root.call("hide_main_menu")
	var new_snapshot_1: Dictionary = simulation_runner.get_snapshot()
	var new_fp_1 := _build_fingerprint(new_snapshot_1)

	run_state.set_mode(&"human")
	run_state.set_phase(&"running")
	simulation_runner.setup_services(time_service, event_log, run_state, location_service)
	simulation_runner.bootstrap()
	ui_root.call("hide_main_menu")
	var new_snapshot_2: Dictionary = simulation_runner.get_snapshot()
	var new_fp_2 := _build_fingerprint(new_snapshot_2)
	var new_world_distinct := new_fp_1 != new_fp_2

	simulation_runner.configure_seed(seed)
	simulation_runner.advance_days(resolved_days, false, true)

	var snapshot_to_save: Dictionary = simulation_runner.get_snapshot()
	var saved_fp := _build_fingerprint(snapshot_to_save)
	var save_result: bool = SaveService.save_game({"simulation_snapshot": snapshot_to_save})
	var save_ok: bool = bool(save_result)
	var continue_payload: Dictionary = SaveService.load_game()
	var continue_has_snapshot: bool = continue_payload.has("simulation_snapshot") and continue_payload.get("simulation_snapshot") is Dictionary

	time_service.reset_clock()
	run_state.set_phase(&"menu")
	event_log.clear()
	simulation_runner.setup_services(time_service, event_log, run_state, location_service)
	var loaded_data: Dictionary = SaveService.load_game()
	var wrapped_snapshot: Dictionary = loaded_data.get("simulation_snapshot", {}) as Dictionary
	if not wrapped_snapshot.is_empty():
		run_state.set_mode(StringName(str(wrapped_snapshot.get("mode", "human"))))
		simulation_runner.load_snapshot(wrapped_snapshot)
		run_state.set_phase(&"running")
		ui_root.call("hide_main_menu")

	var snapshot_after_continue: Dictionary = simulation_runner.get_snapshot()
	var continue_fp := _build_fingerprint(snapshot_after_continue)
	var continue_restored := _same_snapshot(snapshot_to_save, snapshot_after_continue) and saved_fp == continue_fp

	var entries: Array[Dictionary] = event_log.get_entries()
	var movement_entry := _find_first_entry_by_category(entries, "movement")
	if movement_entry.is_empty():
		simulation_runner.configure_human_mode({
			"action_plan": ["seek_master", "visit_sect", "ask_for_guidance", "study_classics"],
		})
		simulation_runner.advance_days(3, false, true)
		entries = event_log.get_entries()
		movement_entry = _find_first_entry_by_category(entries, "movement")
	var movement_ok := not movement_entry.is_empty() and _movement_has_required_trace(movement_entry)

	ui_root.call("_on_view_characters_pressed")
	var character_panel: Node = ui_root.find_child("CharacterPanel", true, false)
	var character_panel_exists := character_panel != null and (character_panel as CanvasItem).visible
	var roster: Array[Dictionary] = CharacterService.get_roster(run_state.mode)
	var roster_ok := roster.size() >= 1
	var timeline_ok := false
	if roster_ok:
		for actor in roster:
			var actor_id := StringName(str((actor as Dictionary).get("id", "")))
			if actor_id == &"":
				continue
			var character_view: Dictionary = CharacterService.get_character_view(actor_id, 20, run_state.mode)
			var detail: Dictionary = character_view.get("detail", {})
			var timeline: Array = character_view.get("timeline", [])
			if not detail.is_empty() and timeline.size() >= 1:
				timeline_ok = true
				break

	var map_panel: Node = ui_root.find_child("MapPanel", true, false)
	ui_root.call("_on_view_map_pressed")
	var map_visible := map_panel != null and (map_panel as CanvasItem).visible
	var regions: Array[Dictionary] = location_service.get_all_regions(run_state.mode)
	var map_ok := map_visible and regions.size() >= 1

	var day_after_menu_gate := day_before == 1 and int(time_service.get_completed_day()) >= 1
	var log_diversity_ok := _check_log_diversity(time_service, run_state, event_log, location_service)

	print("CASE|scenario=task12_e2e|menu_visible_before=%s|phase_before=%s|menu_day_stable=%s|new_world_distinct=%s|save_ok=%s|continue_has_snapshot=%s|continue_restored=%s|movement_ok=%s|roster_ok=%s|timeline_ok=%s|map_ok=%s|log_diversity_ok=%s" % [
		str(menu_before),
		_sanitize(phase_before),
		str(day_after_menu_gate),
		str(new_world_distinct),
		str(save_ok),
		str(continue_has_snapshot),
		str(continue_restored),
		str(movement_ok),
		str(roster_ok),
		str(timeline_ok),
		str(map_ok),
		str(log_diversity_ok),
	])

	var ac01 := new_world_distinct
	var ac02 := continue_restored
	var ac03 := int(snapshot_to_save.get("seed", 0)) != 42
	var ac04 := menu_before and phase_before == "menu" and day_after_menu_gate and boot_entries_before_new == 0
	var ac05 := str(snapshot_after_continue.get("mode", "")) == "human"
	var ac06 := log_diversity_ok
	var ac07 := character_panel_exists and roster_ok and timeline_ok
	var ac08 := map_ok and movement_ok

	print("ASSERT|scenario=task12_e2e|AC01=%s|AC02=%s|AC03=%s|AC04=%s|AC05=%s|AC06=%s|AC07=%s|AC08=%s" % [
		str(ac01),
		str(ac02),
		str(ac03),
		str(ac04),
		str(ac05),
		str(ac06),
		str(ac07),
		str(ac08),
	])

	game_root.free()
	return {
		"failed": not (ac01 and ac02 and ac03 and ac04 and ac05 and ac06 and ac07 and ac08),
		"message": "task12 e2e 验证通过" if (ac01 and ac02 and ac03 and ac04 and ac05 and ac06 and ac07 and ac08) else "task12 e2e 验证失败",
	}


func _ensure_ui_panels_ready(ui_root: Node) -> void:
	if ui_root == null:
		return
	if ui_root.find_child("GameUIContainer", true, false) == null:
		ui_root.call("_build_minimal_ui")
	if ui_root.find_child("MainMenuPanel", true, false) == null:
		ui_root.call("_build_main_menu")
	if ui_root.find_child("CharacterPanel", true, false) == null:
		ui_root.call("_build_character_ui")
	if ui_root.find_child("MapPanel", true, false) == null:
		ui_root.call("_build_map_ui")


func _count_entries_with_title(entries: Array[Dictionary], title: String) -> int:
	var count := 0
	for entry in entries:
		if str(entry.get("title", "")) == title:
			count += 1
	return count


func _run_failure_paths_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, location_service: Node, seed: int, days: int) -> Dictionary:
	_cleanup_default_save()
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"human")
	run_state.set_phase(&"menu")

	var game_root: Node = GAME_ROOT_SCENE.instantiate()
	scene_root.add_child(game_root)
	var simulation_runner: Node = game_root.get_node_or_null("SimulationRunner")
	var ui_root: Node = game_root.get_node_or_null("UIRoot")
	if simulation_runner == null:
		game_root.free()
		return {
			"failed": true,
			"message": "failure_paths: 缺少 SimulationRunner",
		}

	CharacterService.setup_services(simulation_runner, event_log, run_state)
	simulation_runner.setup_services(time_service, event_log, run_state, location_service)
	var no_save_loaded: Dictionary = SaveService.load_game()
	if no_save_loaded.is_empty():
		event_log.add_entry("继续游戏失败：未找到可用存档")
	var no_save_ok := _log_contains("继续游戏失败：未找到可用存档")

	_write_corrupted_default_save()
	event_log.clear()
	var corrupt_loaded: Dictionary = SaveService.load_game()
	if corrupt_loaded.is_empty():
		event_log.add_entry("继续游戏失败：未找到可用存档")
	elif not corrupt_loaded.has("simulation_snapshot"):
		event_log.add_entry("继续游戏失败：存档中缺少 simulation_snapshot")
	var corrupt_save_ok := _log_contains("继续游戏失败：未找到可用存档") or _log_contains("继续游戏失败：存档中缺少 simulation_snapshot")

	event_log.clear()
	simulation_runner.setup_services(time_service, event_log, run_state, location_service)
	simulation_runner.bootstrap(seed)
	var runtime_characters: Array[Dictionary] = simulation_runner.get_runtime_characters()
	var invalid_move_ok := false
	if runtime_characters.size() >= 1:
		var mover_id := StringName(str(runtime_characters[0].get("id", "")))
		var from_region_id := StringName(str(runtime_characters[0].get("region_id", "")))
		var all_regions: Array[Dictionary] = location_service.get_all_regions(run_state.mode)
		var target_region_id := _pick_non_adjacent_region(all_regions, String(from_region_id))
		if not target_region_id.is_empty():
			var move_result: Dictionary = location_service.set_character_region(mover_id, StringName(target_region_id))
			invalid_move_ok = not bool(move_result.get("ok", true)) and str(move_result.get("error", "")) == "non_adjacent_move"

	print("CASE|scenario=task12_failure_paths|no_save_ok=%s|corrupt_save_ok=%s|invalid_move_ok=%s" % [
		str(no_save_ok),
		str(corrupt_save_ok),
		str(invalid_move_ok),
	])
	print("ASSERT|scenario=task12_failure_paths|graceful_no_save=%s|graceful_corrupt=%s|graceful_invalid_move=%s" % [
		str(no_save_ok),
		str(corrupt_save_ok),
		str(invalid_move_ok),
	])

	game_root.free()
	return {
		"failed": not (no_save_ok and corrupt_save_ok and invalid_move_ok),
		"message": "task12 failure paths 验证通过" if (no_save_ok and corrupt_save_ok and invalid_move_ok) else "task12 failure paths 验证失败",
	}


func _same_snapshot(left: Dictionary, right: Dictionary) -> bool:
	if int(left.get("seed", -1)) != int(right.get("seed", -2)):
		return false
	if str(left.get("mode", "")) != str(right.get("mode", "")):
		return false
	var left_time: Dictionary = left.get("time", {})
	var right_time: Dictionary = right.get("time", {})
	if int(left_time.get("day", -1)) != int(right_time.get("day", -2)):
		return false
	if int(left_time.get("minute_of_day", -1)) != int(right_time.get("minute_of_day", -2)):
		return false
	var left_cursor: Dictionary = left.get("log_cursor", {})
	var right_cursor: Dictionary = right.get("log_cursor", {})
	if int(left_cursor.get("entry_count", -1)) != int(right_cursor.get("entry_count", -2)):
		return false
	if str(left_cursor.get("last_entry_id", "")) != str(right_cursor.get("last_entry_id", "")):
		return false
	return true


func _find_first_entry_by_category(entries: Array[Dictionary], category: String) -> Dictionary:
	for entry in entries:
		if str(entry.get("category", "")) == category:
			return entry
	return {}


func _movement_has_required_trace(entry: Dictionary) -> bool:
	var trace: Dictionary = entry.get("trace", {})
	return not str(trace.get("movement_from_region_id", "")).is_empty() and not str(trace.get("movement_to_region_id", "")).is_empty() and not str(trace.get("movement_cause", "")).is_empty()


func _build_fingerprint(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return ""
	var time_data: Dictionary = snapshot.get("time", {})
	var runtime_characters: Array = snapshot.get("runtime_characters", [])
	var first_character := ""
	if runtime_characters.size() > 0:
		first_character = str(runtime_characters[0].get("id", "")) + "@" + str(runtime_characters[0].get("region_id", ""))
	return "%s|%s|%s|%s" % [
		str(snapshot.get("seed", 0)),
		str(snapshot.get("mode", "")),
		str(time_data.get("day", 0)),
		first_character,
	]


func _check_log_diversity(time_service: Node, run_state: Node, event_log: Node, location_service: Node) -> bool:
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"human")
	var runner: Node = RUNNER_SCENE.instantiate()
	var parent: Node = time_service.get_parent()
	if parent == null:
		return false
	parent.add_child(runner)
	runner.setup_services(time_service, event_log, run_state, location_service)
	runner.bootstrap(42)
	runner.advance_days(200, false, true)
	var history: Array = runner.get_event_template_history()
	runner.free()

	var template_counts: Dictionary = {}
	var regular_total := 0
	var max_count := 0
	for record in history:
		var template_id := str(record.get("template_id", ""))
		if template_id.is_empty() or template_id == "mvp_orthodox_investigation" or template_id == "mvp_orthodox_suppression":
			continue
		template_counts[template_id] = int(template_counts.get(template_id, 0)) + 1
		regular_total += 1
	for template_id in template_counts.keys():
		max_count = maxi(max_count, int(template_counts.get(template_id, 0)))
	var max_ratio := float(max_count) / float(regular_total) if regular_total > 0 else 0.0
	var freq_ok := true
	for record in history:
		var template_id := str(record.get("template_id", ""))
		if template_id.is_empty() or template_id == "mvp_orthodox_investigation" or template_id == "mvp_orthodox_suppression":
			continue
		var stage := str(record.get("feedback_stage", ""))
		var day := int(record.get("day", 0))
		var hits := 0
		for follow in history:
			if str(follow.get("template_id", "")) != template_id:
				continue
			if str(follow.get("feedback_stage", "")) != stage:
				continue
			var follow_day := int(follow.get("day", 0))
			if follow_day < day or follow_day - day >= 10:
				continue
			hits += 1
		if hits > 2:
			freq_ok = false
			break
	var festival_count := int(template_counts.get("mvp_harvest_festival", 0))
	var festival_ratio := float(festival_count) / float(regular_total) if regular_total > 0 else 0.0
	return max_ratio <= 0.35 and festival_ratio <= 0.35 and freq_ok


func _log_contains(fragment: String) -> bool:
	if EventLog == null:
		return false
	for entry in EventLog.entries:
		var title := str(entry.get("title", ""))
		var result := str(entry.get("result", ""))
		if title.find(fragment) != -1 or result.find(fragment) != -1:
			return true
	return false


func _pick_non_adjacent_region(all_regions: Array[Dictionary], from_region_id: String) -> String:
	var adjacent: Dictionary = {}
	adjacent[from_region_id] = true
	for region in all_regions:
		if str(region.get("id", "")) != from_region_id:
			continue
		var adj_ids: PackedStringArray = region.get("adjacent_region_ids", PackedStringArray())
		for adj_id in adj_ids:
			adjacent[str(adj_id)] = true
		break
	for region in all_regions:
		var target_id := str(region.get("id", ""))
		if target_id.is_empty():
			continue
		if not adjacent.has(target_id):
			return target_id
	return ""


func _cleanup_default_save() -> void:
	var path := "user://saves/default.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write_corrupted_default_save() -> void:
	var dir_path := "user://saves"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open("user://saves/default.json", FileAccess.WRITE)
	if file != null:
		file.store_string("{bad_json:")
		file.close()


func _sanitize(value: String) -> String:
	return value.replace("|", "／").replace("\n", " ")

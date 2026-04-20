extends SceneTree

const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")
const TIME_SERVICE_SCRIPT := preload("res://autoload/time_service.gd")
const RUN_STATE_SCRIPT := preload("res://autoload/run_state.gd")
const EVENT_LOG_SCRIPT := preload("res://autoload/event_log.gd")
const CHARACTER_SERVICE_SCRIPT := preload("res://autoload/character_service.gd")


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var seed := int(args.get("seed", 77))
	var days := int(args.get("days", 8))
	var mode := StringName(str(args.get("mode", "human")))

	var time_service_info := _ensure_service("TimeService", TIME_SERVICE_SCRIPT)
	var run_state_info := _ensure_service("RunState", RUN_STATE_SCRIPT)
	var event_log_info := _ensure_service("EventLog", EVENT_LOG_SCRIPT)
	var character_service_info := _ensure_service("CharacterService", CHARACTER_SERVICE_SCRIPT)
	var time_service: Node = time_service_info.get("node")
	var run_state: Node = run_state_info.get("node")
	var event_log: Node = event_log_info.get("node")
	var character_service: Node = character_service_info.get("node")

	run_state.set_mode(mode)
	time_service.reset_clock()
	event_log.clear()

	var runner: Node = RUNNER_SCENE.instantiate()
	root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state)
	runner.bootstrap(seed)
	runner.advance_days(days, false, true)

	character_service.setup_services(runner, event_log, run_state)

	var roster: Array[Dictionary] = character_service.get_roster(mode)
	if roster.is_empty():
		print("ASSERT|roster_non_empty=false")
		_cleanup(runner, time_service_info, run_state_info, event_log_info, character_service_info)
		quit(1)
		return

	var first_id := StringName(str(roster[0].get("id", "")))
	var detail: Dictionary = character_service.get_character_detail(first_id, mode)
	var timeline: Array[Dictionary] = character_service.get_character_timeline(first_id, 5, mode)
	var view: Dictionary = character_service.get_character_view(first_id, 5, mode)

	var detail_ok := not detail.is_empty()
	var timeline_ok := not timeline.is_empty()
	var view_ok := not view.is_empty() and view.has("detail") and view.has("timeline")

	print("SMOKE|mode=%s|seed=%d|days=%d|roster=%d|first_id=%s|detail_ok=%s|timeline=%d|view_ok=%s" % [
		str(mode),
		seed,
		days,
		roster.size(),
		str(first_id),
		str(detail_ok),
		timeline.size(),
		str(view_ok),
	])

	var visibility_diff := _visibility_diff_probe(runner, event_log, time_service, character_service)
	print("VISIBILITY|id=%s|human_detail=%s|deity_detail=%s|different=%s" % [
		str(visibility_diff.get("id", "")),
		str(visibility_diff.get("human_detail", false)),
		str(visibility_diff.get("deity_detail", false)),
		str(visibility_diff.get("different", false)),
	])

	print("ASSERT|roster_non_empty=%s|detail_ok=%s|timeline_ok=%s|view_ok=%s|visibility_mode_diff=%s" % [
		str(not roster.is_empty()),
		str(detail_ok),
		str(timeline_ok),
		str(view_ok),
		str(visibility_diff.get("different", false)),
	])

	var failed := not (not roster.is_empty() and detail_ok and timeline_ok and view_ok and bool(visibility_diff.get("different", false)))
	_cleanup(runner, time_service_info, run_state_info, event_log_info, character_service_info)
	quit(1 if failed else 0)


func _visibility_diff_probe(runner: Node, event_log: Node, time_service: Node, character_service: Node) -> Dictionary:
	var marker_id := StringName("task7_visibility_marker")
	if runner == null:
		return {
			"id": str(marker_id),
			"human_detail": false,
			"deity_detail": false,
			"different": false,
		}

	var runtime_characters: Array[Dictionary] = runner.get_runtime_characters()
	if runtime_characters.is_empty():
		return {
			"id": str(marker_id),
			"human_detail": false,
			"deity_detail": false,
			"different": false,
		}

	var marker_base: Dictionary = runtime_characters[0].duplicate(true)
	marker_base["id"] = str(marker_id)
	marker_base["display_name"] = "可见性探针"
	marker_base["summary"] = "仅用于 task7 可见性差异验证"
	runtime_characters.append(marker_base)

	runner.load_snapshot({
		"snapshot_version": 1,
		"seed": int(runner.get_seed()),
		"mode": "human",
		"time": time_service.get_snapshot(),
		"runtime_characters": runtime_characters,
		"world_feedback": {},
		"log_cursor": {
			"entry_count": event_log.get_entries().size(),
			"last_entry_id": _last_entry_id(event_log),
		},
		"event_log_entries": event_log.get_entries(),
	})

	character_service._visibility_index[str(marker_id)] = {
		"human_visible": false,
		"deity_visible": true,
	}

	var human_detail: bool = not character_service.get_character_detail(marker_id, &"human").is_empty()
	var deity_detail: bool = not character_service.get_character_detail(marker_id, &"deity").is_empty()
	return {
		"id": str(marker_id),
		"human_detail": human_detail,
		"deity_detail": deity_detail,
		"different": human_detail != deity_detail,
	}


func _last_entry_id(event_log: Node) -> String:
	var entries: Array = event_log.get_entries()
	if entries.is_empty():
		return ""
	return str(entries[entries.size() - 1].get("entry_id", ""))


func _cleanup(runner: Node, time_service_info: Dictionary, run_state_info: Dictionary, event_log_info: Dictionary, character_service_info: Dictionary) -> void:
	if runner != null:
		runner.free()
	if bool(character_service_info.get("created", false)):
		(character_service_info.get("node") as Node).free()
	if bool(event_log_info.get("created", false)):
		(event_log_info.get("node") as Node).free()
	if bool(run_state_info.get("created", false)):
		(run_state_info.get("node") as Node).free()
	if bool(time_service_info.get("created", false)):
		(time_service_info.get("node") as Node).free()


func _ensure_service(node_name: String, script_resource: Script) -> Dictionary:
	var existing := root.get_node_or_null(node_name)
	if existing != null:
		return {
			"node": existing,
			"created": false,
		}
	var service := Node.new()
	service.name = node_name
	service.set_script(script_resource)
	root.add_child(service)
	return {
		"node": service,
		"created": true,
	}


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {
		"seed": 77,
		"days": 8,
		"mode": "human",
	}
	for arg in raw_args:
		if not arg.begins_with("--"):
			continue
		var trimmed := arg.trim_prefix("--")
		var parts := trimmed.split("=", false, 1)
		var key := parts[0]
		var value := ""
		if parts.size() > 1:
			value = parts[1]
		match key:
			"seed", "days":
				parsed[key] = int(value)
			"mode":
				parsed[key] = value
	return parsed

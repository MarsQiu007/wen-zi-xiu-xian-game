extends Node

const DEFAULT_TIMELINE_LIMIT := 20

var _simulation_runner_node: Node
var _event_log_node: Node
var _run_state_node: Node
var _visibility_index: Dictionary = {}
var _visibility_catalog_path: String = ""


func setup_services(simulation_runner: Node, event_log: Node, run_state: Node) -> void:
	_simulation_runner_node = simulation_runner
	_event_log_node = event_log
	_run_state_node = run_state


func get_roster(mode: StringName = &"", limit: int = 0) -> Array[Dictionary]:
	var runner := _simulation_runner()
	if runner == null or not runner.has_method("get_runtime_characters"):
		return []

	_refresh_visibility_index(runner)
	var resolved_mode := _resolve_mode(mode)
	var roster: Array[Dictionary] = []
	for character in runner.get_runtime_characters():
		var item: Dictionary = character
		var character_id := str(item.get("id", ""))
		if character_id.is_empty():
			continue
		if not _is_character_visible(character_id, resolved_mode):
			continue
		roster.append(_build_roster_item(item))
		if limit > 0 and roster.size() >= limit:
			break
	return roster


func get_character_detail(character_id: StringName, mode: StringName = &"") -> Dictionary:
	var runner := _simulation_runner()
	if runner == null or not runner.has_method("get_runtime_characters"):
		return {}

	var character_key := str(character_id)
	if character_key.is_empty():
		return {}

	_refresh_visibility_index(runner)
	var resolved_mode := _resolve_mode(mode)
	if not _is_character_visible(character_key, resolved_mode):
		return {}

	for character in runner.get_runtime_characters():
		var item: Dictionary = character
		if str(item.get("id", "")) == character_key:
			return {
				"id": character_key,
				"display_name": str(item.get("display_name", "")),
				"summary": str(item.get("summary", "")),
				"tags": _to_string_array(item.get("tags", PackedStringArray())),
				"affiliation": {
					"region_id": str(item.get("region_id", "")),
					"faction_id": str(item.get("faction_id", "")),
					"family_id": str(item.get("family_id", "")),
				},
				"attributes": {
					"talent_rank": int(item.get("talent_rank", 0)),
					"faith_affinity": int(item.get("faith_affinity", 0)),
					"morality_tags": _to_string_array(item.get("morality_tags", PackedStringArray())),
					"temperament_tags": _to_string_array(item.get("temperament_tags", PackedStringArray())),
					"role_tags": _to_string_array(item.get("role_tags", PackedStringArray())),
				},
				"runtime": {
					"focus_state": (item.get("focus_state", {}) as Dictionary).duplicate(true),
					"need_scores": (item.get("need_scores", {}) as Dictionary).duplicate(true),
					"dominant_need": str(item.get("dominant_need", "")),
					"active_goal": (item.get("active_goal", {}) as Dictionary).duplicate(true),
					"last_action": (item.get("last_action", {}) as Dictionary).duplicate(true),
				},
				"visibility": (_visibility_index.get(character_key, {
					"human_visible": true,
					"deity_visible": true,
				}) as Dictionary).duplicate(true),
			}
	return {}


func get_character_timeline(character_id: StringName, limit: int = DEFAULT_TIMELINE_LIMIT, mode: StringName = &"") -> Array[Dictionary]:
	var runner := _simulation_runner()
	if runner == null:
		return []
	var event_log := _event_log()
	if event_log == null or not event_log.has_method("find_entries_by_actor"):
		return []

	var character_key := str(character_id)
	if character_key.is_empty():
		return []

	_refresh_visibility_index(runner)
	var resolved_mode := _resolve_mode(mode)
	if not _is_character_visible(character_key, resolved_mode):
		return []

	var entries: Array[Dictionary] = event_log.find_entries_by_actor(StringName(character_key))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_day := int(a.get("day", 0))
		var b_day := int(b.get("day", 0))
		if a_day != b_day:
			return a_day > b_day
		var a_minute := int(a.get("minute_of_day", 0))
		var b_minute := int(b.get("minute_of_day", 0))
		if a_minute != b_minute:
			return a_minute > b_minute
		return str(a.get("entry_id", "")) > str(b.get("entry_id", ""))
	)

	var resolved_limit := DEFAULT_TIMELINE_LIMIT if limit <= 0 else limit
	var timeline: Array[Dictionary] = []
	for entry in entries:
		timeline.append(_build_timeline_item(entry))
		if timeline.size() >= resolved_limit:
			break
	return timeline


func get_character_view(character_id: StringName, limit: int = DEFAULT_TIMELINE_LIMIT, mode: StringName = &"") -> Dictionary:
	var detail := get_character_detail(character_id, mode)
	if detail.is_empty():
		return {}
	return {
		"detail": detail,
		"timeline": get_character_timeline(character_id, limit, mode),
	}


func _build_roster_item(character: Dictionary) -> Dictionary:
	return {
		"id": str(character.get("id", "")),
		"display_name": str(character.get("display_name", "")),
		"summary": str(character.get("summary", "")),
		"region_id": str(character.get("region_id", "")),
		"faction_id": str(character.get("faction_id", "")),
		"family_id": str(character.get("family_id", "")),
		"focus_tier": str(character.get("focus_state", {}).get("tier", "background")),
		"dominant_need": str(character.get("dominant_need", "")),
		"active_goal_summary": str(character.get("active_goal", {}).get("summary", "")),
		"last_action": (character.get("last_action", {}) as Dictionary).duplicate(true),
	}


func _build_timeline_item(entry: Dictionary) -> Dictionary:
	return {
		"entry_id": str(entry.get("entry_id", "")),
		"day": int(entry.get("day", 0)),
		"minute_of_day": int(entry.get("minute_of_day", 0)),
		"timestamp": str(entry.get("timestamp", "")),
		"category": str(entry.get("category", "")),
		"title": str(entry.get("title", "")),
		"result": str(entry.get("result", "")),
		"direct_cause": str(entry.get("direct_cause", "")),
		"related_ids": _to_string_array(entry.get("related_ids", PackedStringArray())),
		"trace": (entry.get("trace", {}) as Dictionary).duplicate(true),
	}


func _resolve_mode(requested_mode: StringName) -> StringName:
	if requested_mode != &"":
		return requested_mode
	var run_state := _run_state()
	if run_state != null:
		var current_mode = run_state.get("mode")
		if current_mode != null:
			return StringName(str(current_mode))
	return &"human"


func _simulation_runner() -> Node:
	if is_instance_valid(_simulation_runner_node):
		return _simulation_runner_node
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("GameRoot/SimulationRunner")


func _event_log() -> Node:
	if is_instance_valid(_event_log_node):
		return _event_log_node
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("EventLog")


func _run_state() -> Node:
	if is_instance_valid(_run_state_node):
		return _run_state_node
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("RunState")


func _refresh_visibility_index(runner: Node) -> void:
	if runner == null or not runner.has_method("get_catalog_path"):
		_visibility_index = {}
		_visibility_catalog_path = ""
		return

	var catalog_path := str(runner.get_catalog_path())
	if catalog_path == _visibility_catalog_path and not _visibility_index.is_empty():
		return

	_visibility_catalog_path = catalog_path
	_visibility_index = {}
	if catalog_path.is_empty():
		return

	var catalog := load(catalog_path)
	if catalog == null or not catalog.has_method("get"):
		return

	var resources: Array = catalog.get("characters")
	for character in resources:
		if character == null or not character.has_method("get"):
			continue
		var character_id := str(character.get("id"))
		if character_id.is_empty():
			continue
		var human_visible = character.get("human_visible")
		var deity_visible = character.get("deity_visible")
		if human_visible == null:
			human_visible = true
		if deity_visible == null:
			deity_visible = true
		_visibility_index[character_id] = {
			"human_visible": bool(human_visible),
			"deity_visible": bool(deity_visible),
		}


func _is_character_visible(character_id: String, mode: StringName) -> bool:
	var visibility: Dictionary = _visibility_index.get(character_id, {
		"human_visible": true,
		"deity_visible": true,
	})
	match mode:
		&"human":
			return bool(visibility.get("human_visible", true))
		&"deity":
			return bool(visibility.get("deity_visible", true))
		_:
			return true


func _to_string_array(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		for item in value:
			result.append(str(item))
	elif value is Array:
		for item in value:
			result.append(str(item))
	return result

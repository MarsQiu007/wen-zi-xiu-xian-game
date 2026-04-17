extends Node

signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 200

var entries: Array[Dictionary] = []
var _next_entry_id: int = 1


func clear() -> void:
	entries.clear()
	_next_entry_id = 1


func add_entry(entry: String) -> Dictionary:
	if entry.is_empty():
		return {}
	return add_event({
		"category": "system",
		"title": entry,
		"direct_cause": "system_note",
		"result": entry,
	})


func add_event(event_data: Dictionary) -> Dictionary:
	var normalized := _normalize_entry(event_data)
	if str(normalized.get("title", "")).is_empty():
		return {}

	entries.append(normalized)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()

	entry_added.emit(normalized)
	return normalized.duplicate(true)


func get_entries() -> Array[Dictionary]:
	return entries.duplicate()


func get_entry_by_id(entry_id: String) -> Dictionary:
	for entry in entries:
		if str(entry.get("entry_id", "")) == entry_id:
			return entry.duplicate(true)
	return {}


func find_entries_by_actor(actor_id: StringName) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry in entries:
		var actors: PackedStringArray = entry.get("actor_ids", PackedStringArray())
		if actors.has(str(actor_id)):
			results.append(entry.duplicate(true))
	return results


func find_entries_by_cause(direct_cause: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry in entries:
		if str(entry.get("direct_cause", "")) == direct_cause:
			results.append(entry.duplicate(true))
	return results


func get_summary_lines(limit: int = 20) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var start_index := maxi(0, entries.size() - maxi(0, limit))
	for index in range(start_index, entries.size()):
		var entry := entries[index]
		var actors: PackedStringArray = entry.get("actor_ids", PackedStringArray())
		var trace: Dictionary = entry.get("trace", {})
		lines.append("ENTRY|id=%s|day=%s|minute=%s|category=%s|title=%s|actors=%s|cause=%s|result=%s|pause=%s|trace=%s" % [
			_sanitize(str(entry.get("entry_id", ""))),
			str(entry.get("day", 0)),
			str(entry.get("minute_of_day", 0)),
			_sanitize(str(entry.get("category", "system"))),
			_sanitize(str(entry.get("title", ""))),
			_sanitize(",".join(actors)),
			_sanitize(str(entry.get("direct_cause", ""))),
			_sanitize(str(entry.get("result", ""))),
			str(entry.get("pause_required", false)),
			_sanitize(_trace_to_text(trace)),
		])
	return lines


func _normalize_entry(event_data: Dictionary) -> Dictionary:
	var entry_id := str(event_data.get("entry_id", ""))
	if entry_id.is_empty():
		entry_id = "evt_%04d" % _next_entry_id
		_next_entry_id += 1

	var actor_ids := _to_string_array(event_data.get("actor_ids", PackedStringArray()))
	var related_ids := _to_string_array(event_data.get("related_ids", PackedStringArray()))
	var trace_input = event_data.get("trace", {})
	var trace: Dictionary = trace_input.duplicate(true) if trace_input is Dictionary else {}
	var snapshot: Dictionary = _time_snapshot()
	var day_value := int(event_data.get("day", snapshot.get("completed_day", 1)))
	var minute_value := int(event_data.get("minute_of_day", snapshot.get("minute_of_day", 0)))
	var timestamp := str(event_data.get("timestamp", snapshot.get("clock_text", "")))
	var title := str(event_data.get("title", ""))
	var result := str(event_data.get("result", title))

	return {
		"entry_id": entry_id,
		"category": str(event_data.get("category", "world")),
		"title": title,
		"actor_ids": actor_ids,
		"related_ids": related_ids,
		"direct_cause": str(event_data.get("direct_cause", "daily_tick")),
		"result": result,
		"pause_required": bool(event_data.get("pause_required", false)),
		"day": day_value,
		"minute_of_day": minute_value,
		"timestamp": timestamp,
		"trace": trace,
	}


func _to_string_array(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		for item in value:
			result.append(str(item))
	elif value is Array:
		for item in value:
			result.append(str(item))
	return result


func _trace_to_text(trace: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var keys := trace.keys()
	keys.sort()
	for key in keys:
		parts.append("%s:%s" % [str(key), str(trace[key])])
	return ",".join(parts)


func _sanitize(value: String) -> String:
	return value.replace("|", "／").replace("\n", " ")


func _time_snapshot() -> Dictionary:
	if not is_inside_tree():
		return {
			"day": 1,
			"completed_day": 1,
			"minute_of_day": 0,
			"total_minutes": 0,
			"clock_text": "第1天 00:00",
		}
	var tree := get_tree()
	if tree == null or tree.root == null:
		return {
			"day": 1,
			"completed_day": 1,
			"minute_of_day": 0,
			"total_minutes": 0,
			"clock_text": "第1天 00:00",
		}
	var time_service := tree.root.get_node_or_null("TimeService")
	if time_service != null and time_service.has_method("get_snapshot"):
		return time_service.get_snapshot()
	return {
		"day": 1,
		"completed_day": 1,
		"minute_of_day": 0,
		"total_minutes": 0,
		"clock_text": "第1天 00:00",
	}

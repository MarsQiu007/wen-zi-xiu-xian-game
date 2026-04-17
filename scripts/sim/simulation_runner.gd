extends Node
class_name SimulationRunner

const DEFAULT_SEED := 42
const CATALOG_PATH := "res://resources/world/world_data_catalog.tres"
const SeededRandomScript = preload("res://scripts/sim/seeded_random.gd")

signal bootstrapped
signal day_resolved(report: Dictionary)
signal pause_requested(checkpoint: Dictionary)

var _catalog: Resource
var _random: RefCounted = SeededRandomScript.new()
var _seed: int = DEFAULT_SEED
var _runtime_characters: Array[Dictionary] = []
var _pending_checkpoint: Dictionary = {}
var _resolved_days: int = 0
var _pause_count: int = 0
var _event_log_node: Node
var _time_service_node: Node
var _run_state_node: Node


func setup_services(time_service: Node, event_log: Node, run_state: Node) -> void:
	_time_service_node = time_service
	_event_log_node = event_log
	_run_state_node = run_state


func bootstrap(seed: int = DEFAULT_SEED) -> void:
	_catalog = load(CATALOG_PATH)
	reset_simulation(seed)
	_event_log().add_entry("SimulationRunner 已就绪")
	bootstrapped.emit()


func reset_simulation(seed: int = DEFAULT_SEED) -> void:
	_seed = seed
	_random.set_seed(seed)
	_resolved_days = 0
	_pause_count = 0
	_pending_checkpoint = {}
	_runtime_characters = _build_runtime_characters()
	_time_service().reset_clock()
	_event_log().clear()
	_run_state().set_phase(&"ready")
	_event_log().add_event({
		"category": "system",
		"title": "模拟已重置",
		"direct_cause": "reset_simulation",
		"result": "固定种子 %d 已装载，运行时角色 %d 名。" % [_seed, _runtime_characters.size()],
		"trace": {
			"seed": _seed,
			"character_count": _runtime_characters.size(),
		},
	})


func configure_seed(seed: int) -> void:
	_seed = seed
	_random.set_seed(seed)


func get_seed() -> int:
	return _seed


func get_runtime_characters() -> Array[Dictionary]:
	return _runtime_characters.duplicate(true)


func has_pending_pause() -> bool:
	return not _pending_checkpoint.is_empty()


func get_pending_checkpoint() -> Dictionary:
	return _pending_checkpoint.duplicate(true)


func advance_one_day(stop_on_pause: bool = true, auto_resolve_pause: bool = false) -> Dictionary:
	if _catalog == null:
		bootstrap(_seed)

	if has_pending_pause():
		if auto_resolve_pause:
			resolve_pending_checkpoint(&"auto_continue")
		elif stop_on_pause:
			return _build_pause_report(0)

	_run_state().set_phase(&"simulating")
	var day_report: Dictionary = _time_service().advance_day()
	var simulated_day: int = int(day_report.get("completed_day", _time_service().get_completed_day()))
	var event_entry: Dictionary = _resolve_daily_event(simulated_day)
	var report := {
		"requested_days": 1,
		"advanced_days": 1,
		"resolved_day": simulated_day,
		"entry_id": str(event_entry.get("entry_id", "")),
		"title": str(event_entry.get("title", "")),
		"paused": bool(event_entry.get("pause_required", false)),
		"pause_title": str(event_entry.get("title", "")),
		"pause_count": _pause_count,
		"total_minutes": _time_service().get_total_minutes(),
		"entries": _event_log().entries.size(),
		"seed": _seed,
	}
	_resolved_days += 1
	day_resolved.emit(report)

	if bool(event_entry.get("pause_required", false)):
		_pause_count += 1
		_pending_checkpoint = {
			"day": simulated_day,
			"title": event_entry.get("title", ""),
			"entry_id": event_entry.get("entry_id", ""),
			"direct_cause": event_entry.get("direct_cause", ""),
			"result": event_entry.get("result", ""),
			"actors": event_entry.get("actor_ids", PackedStringArray()),
			"trace": event_entry.get("trace", {}),
		}
		_run_state().set_phase(&"paused_for_choice")
		pause_requested.emit(get_pending_checkpoint())
		if auto_resolve_pause:
			resolve_pending_checkpoint(&"auto_continue")
		elif stop_on_pause:
			report["pause_count"] = _pause_count
			return report

	_run_state().set_phase(&"ready")
	report["pause_count"] = _pause_count
	return report


func advance_days(days_to_advance: int, stop_on_pause: bool = true, auto_resolve_pause: bool = false) -> Dictionary:
	var requested_days := maxi(0, days_to_advance)
	var advanced_days := 0
	var paused := false
	var pause_title := ""
	var last_entry_id := ""

	for _index in range(requested_days):
		var report := advance_one_day(stop_on_pause, auto_resolve_pause)
		advanced_days += int(report.get("advanced_days", 0))
		last_entry_id = str(report.get("entry_id", last_entry_id))
		if bool(report.get("paused", false)):
			paused = true
			pause_title = str(report.get("pause_title", ""))
			if stop_on_pause and not auto_resolve_pause:
				break

	return {
		"requested_days": requested_days,
		"advanced_days": advanced_days,
		"paused": paused,
		"pause_title": pause_title,
		"pause_count": _pause_count,
		"last_entry_id": last_entry_id,
		"resolved_days": _resolved_days,
		"entries": _event_log().entries.size(),
		"seed": _seed,
		"total_minutes": _time_service().get_total_minutes(),
	}


func resolve_pending_checkpoint(choice_id: StringName = &"auto_continue") -> Dictionary:
	if _pending_checkpoint.is_empty():
		return {}

	var checkpoint: Dictionary = _pending_checkpoint.duplicate(true)
	_pending_checkpoint = {}
	_run_state().set_phase(&"ready")
	_event_log().add_event({
		"category": "choice_resolution",
		"title": "关键节点已续行",
		"actor_ids": checkpoint.get("actors", PackedStringArray()),
		"direct_cause": str(checkpoint.get("direct_cause", "")),
		"result": "%s 在关键节点后选择 %s，系统继续推进。" % [str(checkpoint.get("title", "事件")), str(choice_id)],
		"day": int(checkpoint.get("day", _time_service().get_completed_day())),
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"resolved_entry_id": str(checkpoint.get("entry_id", "")),
			"choice_id": str(choice_id),
			"seed": _seed,
		},
	})
	return checkpoint


func _resolve_daily_event(simulated_day: int) -> Dictionary:
	var template: Resource = _pick_event_template(simulated_day)
	var actor: Dictionary = _pick_actor()
	var region_id := str(actor.get("region_id", ""))
	var faction_id := str(actor.get("faction_id", ""))
	var region: Resource = _catalog.find_region(StringName(region_id)) if _catalog != null and not region_id.is_empty() else null
	var faction: Resource = _catalog.find_faction(StringName(faction_id)) if _catalog != null and not faction_id.is_empty() else null
	var direct_cause: String = _pick_direct_cause(template, simulated_day)
	var roll: int = _random.next_int(100)
	var pause_required: bool = _is_pause_required(template)
	var result: String = _build_result_text(template, actor, region, faction, direct_cause, roll)
	return _event_log().add_event({
		"category": str(_resource_get(template, "event_type", "world")),
		"title": str(_resource_get(template, "display_name", "日常事件")),
		"actor_ids": [str(actor.get("id", ""))],
		"related_ids": _build_related_ids(region, faction),
		"direct_cause": direct_cause,
		"result": result,
		"pause_required": pause_required,
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"seed": _seed,
			"template_id": str(_resource_get(template, "id", "")),
			"actor_id": str(actor.get("id", "")),
			"region_id": str(_resource_get(region, "id", "")) if region != null else "",
			"faction_id": str(_resource_get(faction, "id", "")) if faction != null else "",
			"roll": roll,
			"day": simulated_day,
		},
	})


func _pick_event_template(simulated_day: int) -> Resource:
	var templates: Array = _catalog.get("event_templates") if _catalog != null else []
	if templates.is_empty():
		return null
	var index: int = (simulated_day - 1) % templates.size()
	return templates[index]


func _pick_actor() -> Dictionary:
	if _runtime_characters.is_empty():
		return {
			"id": "unknown_actor",
			"display_name": "无名氏",
			"region_id": "",
			"faction_id": "",
		}
	var index: int = _random.pick_index(_runtime_characters)
	return _runtime_characters[index].duplicate(true)


func _pick_direct_cause(template: Resource, simulated_day: int) -> String:
	if template == null:
		return "daily_tick"
	var triggers: PackedStringArray = _resource_get(template, "trigger_tags", PackedStringArray())
	if triggers.is_empty():
		return "daily_tick_%d" % simulated_day
	var index: int = _random.pick_index(triggers)
	if index < 0:
		return "daily_tick_%d" % simulated_day
	return str(triggers[index])


func _is_pause_required(template: Resource) -> bool:
	if template == null:
		return false
	var pause_behavior := str(_resource_get(template, "pause_behavior", "auto"))
	return pause_behavior == "require_choice"


func _build_result_text(template: Resource, actor: Dictionary, region: Resource, faction: Resource, direct_cause: String, roll: int) -> String:
	var actor_name := str(actor.get("display_name", "无名氏"))
	var region_name := str(_resource_get(region, "display_name", "无名地带")) if region != null else "无名地带"
	var faction_name := str(_resource_get(faction, "display_name", "无归属势力")) if faction != null else "无归属势力"
	var title := str(_resource_get(template, "display_name", "日常事件")) if template != null else "日常事件"
	var outcome_variants: Array[String] = [
		"获得了稳定反馈",
		"引起了周围人的注意",
		"让后续选择变得更明确",
	]
	var outcome_text: String = outcome_variants[roll % outcome_variants.size()]
	return "%s 在 %s 遭遇 %s，受 %s 驱动，与 %s 发生联系，%s。" % [actor_name, region_name, title, direct_cause, faction_name, outcome_text]


func _build_related_ids(region: Resource, faction: Resource) -> PackedStringArray:
	var related: PackedStringArray = PackedStringArray()
	if region != null:
		related.append(str(_resource_get(region, "id", "")))
	if faction != null:
		related.append(str(_resource_get(faction, "id", "")))
	return related


func _build_runtime_characters() -> Array[Dictionary]:
	var characters: Array[Dictionary] = []
	if _catalog == null:
		return characters
	var resources: Array = _catalog.get("characters")
	for character in resources:
		if character == null:
			continue
		characters.append({
			"id": str(_resource_get(character, "id", "")),
			"display_name": str(_resource_get(character, "display_name", "")),
			"region_id": str(_resource_get(character, "region_id", "")),
			"faction_id": str(_resource_get(character, "faction_id", "")),
			"family_id": str(_resource_get(character, "family_id", "")),
			"talent_rank": int(_resource_get(character, "talent_rank", 0)),
			"faith_affinity": int(_resource_get(character, "faith_affinity", 0)),
			"role_tags": _resource_get(character, "role_tags", PackedStringArray()),
			"life_goal_summary": str(_resource_get(character, "life_goal_summary", "")),
		})
	return characters


func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	return fallback if value == null else value


func _build_pause_report(advanced_days: int) -> Dictionary:
	return {
		"requested_days": 1,
		"advanced_days": advanced_days,
		"resolved_day": _time_service().get_completed_day(),
		"entry_id": str(_pending_checkpoint.get("entry_id", "")),
		"title": str(_pending_checkpoint.get("title", "")),
		"paused": true,
		"pause_title": str(_pending_checkpoint.get("title", "")),
		"pause_count": _pause_count,
		"total_minutes": _time_service().get_total_minutes(),
		"entries": _event_log().entries.size(),
		"seed": _seed,
	}


func _event_log() -> Node:
	if _event_log_node != null:
		return _event_log_node
	var tree := get_tree()
	return tree.root.get_node_or_null("EventLog") if tree != null and tree.root != null else null


func _time_service() -> Node:
	if _time_service_node != null:
		return _time_service_node
	var tree := get_tree()
	return tree.root.get_node_or_null("TimeService") if tree != null and tree.root != null else null


func _run_state() -> Node:
	if _run_state_node != null:
		return _run_state_node
	var tree := get_tree()
	return tree.root.get_node_or_null("RunState") if tree != null and tree.root != null else null

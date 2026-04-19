extends Node
class_name SimulationRunner

const CATALOG_PATH := "res://resources/world/world_data_catalog.tres"
const ORTHODOX_INVESTIGATION_EVENT_ID := &"mvp_orthodox_investigation"
const ORTHODOX_SUPPRESSION_EVENT_ID := &"mvp_orthodox_suppression"
const EVENT_TEMPLATE_COOLDOWN_DAYS := 2
const EVENT_TEMPLATE_FREQUENCY_WINDOW := 10
const EVENT_TEMPLATE_FREQUENCY_CAP := 2
const EVENT_TEMPLATE_DIVERSITY_WINDOW := 30
const SeededRandomScript = preload("res://scripts/sim/seeded_random.gd")
const HumanModeRuntimeScript = preload("res://scripts/modes/human/human_mode_runtime.gd")
const DeityModeRuntimeScript = preload("res://scripts/modes/deity/deity_mode_runtime.gd")
const WorldGeneratorScript = preload("res://scripts/world/world_generator.gd")
const NpcDecisionEngineScript = preload("res://scripts/npc/npc_decision_engine.gd")
const NpcMemorySystemScript = preload("res://scripts/npc/npc_memory_system.gd")
const RelationshipNetworkScript = preload("res://scripts/npc/relationship_network.gd")
const NpcBehaviorLibraryScript = preload("res://scripts/npc/npc_behavior_library.gd")
const CharacterCreationParamsScript = preload("res://scripts/data/character_creation_params.gd")
const WorldSeedDataScript = preload("res://scripts/data/world_seed_data.gd")
const RelationshipEdgeScript = preload("res://scripts/data/relationship_edge.gd")
const NpcMemoryEntryScript = preload("res://scripts/data/npc_memory_entry.gd")

const NEED_RESOURCE := &"resource_pressure"
const NEED_STABILITY := &"stability"
const NEED_REPUTATION := &"reputation"
const NEED_BELONGING := &"belonging"
const SNAPSHOT_VERSION := 1
const SNAPSHOT_ERROR_OK := "ok"
const SNAPSHOT_ERROR_INVALID_ROOT_TYPE := "invalid_root_type"
const SNAPSHOT_ERROR_MISSING_FIELD := "missing_field"
const SNAPSHOT_ERROR_INVALID_FIELD_TYPE := "invalid_field_type"
const SNAPSHOT_ERROR_LOG_CURSOR_MISMATCH := "log_cursor_mismatch"
const WORLD_FEEDBACK_NUMERIC_LIMITS := {
	"family_pressure": {"min": 1, "max": 20},
	"sect_interest": {"min": 1, "max": 20},
	"cult_presence": {"min": 1, "max": 20},
	"faith_activity": {"min": 1, "max": 20},
	"orthodox_hostility": {"min": 1, "max": 20},
	"human_faith_exposure": {"min": 0, "max": 20},
	"suppression_pressure": {"min": 0, "max": 20},
	"city_alert": {"min": 1, "max": 20},
	"beast_pressure": {"min": 1, "max": 20},
	"ghost_pressure": {"min": 1, "max": 20},
	"secret_realm_heat": {"min": 1, "max": 20},
}

signal bootstrapped
signal day_resolved(report: Dictionary)
signal pause_requested(checkpoint: Dictionary)

var _catalog: Resource
var _catalog_path: String = CATALOG_PATH
var _random: RefCounted = SeededRandomScript.new()
var _seed: int = 0
var _seed_nonce: int = 0
var _runtime_characters: Array[Dictionary] = []
var _pending_checkpoint: Dictionary = {}
var _resolved_days: int = 0
var _pause_count: int = 0
var _event_log_node: Node
var _time_service_node: Node
var _run_state_node: Node
var _location_service_node: Node
var _task7_enabled: bool = false
var _human_mode_runtime: RefCounted = HumanModeRuntimeScript.new()
var _human_mode_options: Dictionary = {}
var _human_runtime: Dictionary = {}
var _deity_mode_runtime: RefCounted = DeityModeRuntimeScript.new()
var _deity_mode_options: Dictionary = {}
var _deity_runtime: Dictionary = {}
var _world_feedback_state: Dictionary = {}
var _event_template_history: Array[Dictionary] = []
var _world_generator: RefCounted = WorldGeneratorScript.new()
var _decision_engine: RefCounted = NpcDecisionEngineScript.new()
var _memory_system: RefCounted = NpcMemorySystemScript.new()
var _relationship_network: RefCounted = RelationshipNetworkScript.new()
var _behavior_library: RefCounted = NpcBehaviorLibraryScript.new()
var _npc_decision_intervals: Dictionary = {}
var _creation_params_snapshot: Dictionary = {}
var _world_seed_snapshot: Dictionary = {}


func setup_services(time_service: Node, event_log: Node, run_state: Node, location_service: Node = null) -> void:
	_time_service_node = time_service
	_event_log_node = event_log
	_run_state_node = run_state
	_location_service_node = location_service


# 已弃用：保留旧入口以兼容历史调用，建议改用 bootstrap_from_creation。
func bootstrap(new_seed: int = -1) -> void:
	_catalog = load(_catalog_path)
	reset_simulation(new_seed)
	_event_log().add_entry("SimulationRunner 已就绪")
	bootstrapped.emit()


func bootstrap_from_creation(creation_params: Dictionary, seed_data: Dictionary) -> void:
	if _catalog == null:
		_catalog = load(_catalog_path)

	var creation_resource := CharacterCreationParamsScript.from_dict(_decorate_snapshot_version(creation_params, 1))
	var normalized_seed_data: Dictionary = seed_data.duplicate(true)
	if int(normalized_seed_data.get("seed_value", -1)) < 0:
		normalized_seed_data["seed_value"] = _resolve_seed(-1)
	var seed_resource := WorldSeedDataScript.from_dict(_decorate_snapshot_version(normalized_seed_data, 1))

	_creation_params_snapshot = creation_resource.to_dict()
	_world_seed_snapshot = seed_resource.to_dict()
	_seed = int(seed_resource.seed_value)
	_random.set_seed(_seed)

	var generated_world: Dictionary = _world_generator.generate(seed_resource)
	var generated_characters: Array = generated_world.get("characters", [])
	var runtime_characters: Array[Dictionary] = []
	for character in generated_characters:
		if character is Dictionary:
			runtime_characters.append((character as Dictionary).duplicate(true))
	_runtime_characters = runtime_characters

	_relationship_network = RelationshipNetworkScript.new()
	var generated_relationships: Array = generated_world.get("relationships", [])
	for relation_data in generated_relationships:
		if not (relation_data is Dictionary):
			continue
		var edge := RelationshipEdgeScript.from_dict(_decorate_snapshot_version((relation_data as Dictionary), 1))
		_relationship_network.add_edge(edge)

	_memory_system = NpcMemorySystemScript.new()
	_decision_engine = NpcDecisionEngineScript.new()
	_behavior_library = NpcBehaviorLibraryScript.new()
	_npc_decision_intervals.clear()

	_resolved_days = 0
	_pause_count = 0
	_pending_checkpoint = {}
	_task7_enabled = false
	_human_runtime = {}
	_deity_runtime = {}
	_world_feedback_state = {}
	_event_template_history.clear()

	if _time_service() != null:
		_time_service().reset_clock()
	if _event_log() != null:
		_event_log().clear()

	var location_service := _location_service()
	if location_service != null and location_service.has_method("bind_runtime"):
		location_service.bind_runtime(_catalog, _runtime_characters)

	if _run_state() != null:
		_run_state().set_phase(&"ready")
	if _event_log() != null:
		_event_log().add_event({
			"category": "system",
			"title": "世界初始化完成",
			"direct_cause": "bootstrap_from_creation",
			"result": "已根据角色创建参数和种子生成世界，NPC %d 名。" % _runtime_characters.size(),
			"trace": {
				"seed": _seed,
				"character_count": _runtime_characters.size(),
				"relationship_count": _relationship_network.edge_count(),
			},
		})
	bootstrapped.emit()


func reset_simulation(new_seed: int = -1) -> void:
	_seed = _resolve_seed(new_seed)
	_random.set_seed(_seed)
	_resolved_days = 0
	_pause_count = 0
	_pending_checkpoint = {}
	_runtime_characters = _build_runtime_characters()
	var location_service := _location_service()
	if location_service != null and location_service.has_method("bind_runtime"):
		location_service.bind_runtime(_catalog, _runtime_characters)
	_task7_enabled = _has_task7_fixture_characters()
	_human_runtime = _build_human_runtime()
	_deity_runtime = _build_deity_runtime()
	_world_feedback_state = _build_world_feedback_state()
	_event_template_history.clear()
	_creation_params_snapshot = {}
	_world_seed_snapshot = {
		"snapshot_version": 1,
		"seed_value": _seed,
		"region_count": 7,
		"npc_count": 30,
		"resource_density": 0.5,
		"monster_density": 0.3,
	}
	_initialize_npc_runtime_supports()
	_time_service().reset_clock()
	_event_log().clear()
	_run_state().set_phase(&"ready")
	_event_log().add_event({
		"category": "system",
		"title": "模拟已重置",
		"direct_cause": "reset_simulation",
		"result": "种子 %d 已装载，运行时角色 %d 名。" % [_seed, _runtime_characters.size()],
		"trace": {
			"seed": _seed,
			"character_count": _runtime_characters.size(),
			"catalog_path": _catalog_path,
			"task7_enabled": _task7_enabled,
			"human_opening_type": str(_human_runtime.get("opening_type", "")),
			"deity_id": str(_deity_runtime.get("deity", {}).get("id", "")),
		},
	})


func configure_seed(new_seed: int) -> void:
	_seed = new_seed
	_random.set_seed(new_seed)


func _resolve_seed(requested_seed: int) -> int:
	if requested_seed >= 0:
		return requested_seed
	return _generate_runtime_seed()


func _generate_runtime_seed() -> int:
	_seed_nonce += 1
	var ticks := Time.get_ticks_usec()
	var unix_time := int(Time.get_unix_time_from_system())
	var mixed := int((ticks & 0x7fffffff) ^ (unix_time & 0x7fffffff) ^ (_seed_nonce & 0x7fffffff))
	return 1 if mixed == 0 else mixed


func configure_catalog_path(catalog_path: String) -> void:
	_catalog_path = CATALOG_PATH if catalog_path.is_empty() else catalog_path
	_catalog = null


func configure_human_mode(options: Dictionary) -> void:
	_human_mode_options = options.duplicate(true)


func configure_deity_mode(options: Dictionary) -> void:
	_deity_mode_options = options.duplicate(true)


func get_catalog_path() -> String:
	return _catalog_path


func get_seed() -> int:
	return _seed


func get_runtime_characters() -> Array[Dictionary]:
	return _runtime_characters.duplicate(true)


func get_human_runtime() -> Dictionary:
	return _human_runtime.duplicate(true)


func get_deity_runtime() -> Dictionary:
	return _deity_runtime.duplicate(true)


func get_event_template_history() -> Array[Dictionary]:
	return _event_template_history.duplicate(true)


func get_snapshot() -> Dictionary:
	var mode := ""
	if _run_state() != null:
		mode = str(_run_state().mode)

	var time_snapshot: Dictionary = {
		"day": 1,
		"minute_of_day": 0,
	}
	if _time_service() != null and _time_service().has_method("get_snapshot"):
		time_snapshot = _normalize_snapshot_value(_time_service().get_snapshot())
	var speed_tier_snapshot := int(time_snapshot.get("speed_tier", 2))
	if _time_service() != null:
		speed_tier_snapshot = int(_time_service().get("speed_tier"))

	var event_entries: Array = []
	if _event_log() != null and _event_log().has_method("get_entries"):
		event_entries = _normalize_snapshot_value(_event_log().get_entries())
	var last_entry_id := ""
	if not event_entries.is_empty():
		last_entry_id = str(event_entries[event_entries.size() - 1].get("entry_id", ""))

	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"seed": _seed,
		"mode": mode,
		"time": time_snapshot,
		"runtime_characters": _normalize_snapshot_value(_runtime_characters),
		"world_feedback": _normalize_snapshot_value(_world_feedback_state),
		"creation_params": _normalize_snapshot_value(_creation_params_snapshot),
		"world_seed": _normalize_snapshot_value(_world_seed_snapshot),
		"relationship_network": _normalize_snapshot_value(_relationship_network.to_dict() if _relationship_network != null else {}),
		"memory_system": _normalize_snapshot_value(_memory_system.to_dict() if _memory_system != null else {}),
		"npc_decision_intervals": _normalize_snapshot_value(_npc_decision_intervals),
		"speed_tier": speed_tier_snapshot,
		"log_cursor": {
			"entry_count": event_entries.size(),
			"last_entry_id": last_entry_id,
		},
		"event_log_entries": event_entries,
	}


func load_snapshot(snapshot: Dictionary) -> Dictionary:
	var validation := _validate_snapshot_payload(snapshot)
	if not bool(validation.get("ok", false)):
		return validation

	var normalized: Dictionary = validation.get("snapshot", {})
	var snapshot_seed := int(normalized.get("seed", _seed))
	var snapshot_mode := StringName(str(normalized.get("mode", "human")))
	var time_data: Dictionary = normalized.get("time", {})
	var restored_day := int(time_data.get("day", 1))
	var restored_minute := int(time_data.get("minute_of_day", 0))
	var runtime_characters_data: Array = normalized.get("runtime_characters", [])
	var world_feedback_data: Dictionary = normalized.get("world_feedback", {})
	var creation_params_data: Dictionary = normalized.get("creation_params", {})
	var world_seed_data: Dictionary = normalized.get("world_seed", {})
	var relationship_network_data: Dictionary = normalized.get("relationship_network", {})
	var memory_system_data: Dictionary = normalized.get("memory_system", {})
	var npc_decision_intervals_data: Dictionary = normalized.get("npc_decision_intervals", {})
	var speed_tier_data := int(normalized.get("speed_tier", 2))
	var log_cursor: Dictionary = normalized.get("log_cursor", {})
	var event_entries: Array = normalized.get("event_log_entries", [])

	if _run_state() != null:
		_run_state().set_mode(snapshot_mode)
	if _catalog == null:
		_catalog = load(_catalog_path)

	reset_simulation(snapshot_seed)

	if _time_service() != null:
		_time_service().reset_clock(restored_day, restored_minute)
		if _time_service().has_method("set_speed_tier"):
			_time_service().set_speed_tier(speed_tier_data)

	var restored_runtime_characters: Array[Dictionary] = []
	for character in runtime_characters_data:
		restored_runtime_characters.append((character as Dictionary).duplicate(true))
	_runtime_characters = restored_runtime_characters
	var location_service := _location_service()
	if location_service != null and location_service.has_method("bind_runtime"):
		location_service.bind_runtime(_catalog, _runtime_characters)
	_world_feedback_state = world_feedback_data.duplicate(true)
	_creation_params_snapshot = creation_params_data.duplicate(true)
	_world_seed_snapshot = world_seed_data.duplicate(true)
	_relationship_network = RelationshipNetworkScript.from_dict(relationship_network_data)
	_memory_system = NpcMemorySystemScript.from_dict(memory_system_data)
	_decision_engine = NpcDecisionEngineScript.new()
	_behavior_library = NpcBehaviorLibraryScript.new()
	_npc_decision_intervals = npc_decision_intervals_data.duplicate(true)

	if _event_log() != null:
		_event_log().clear()
		for entry in event_entries:
			_event_log().add_event((entry as Dictionary).duplicate(true))

	var restored_entry_count := event_entries.size()
	if _event_log() != null and _event_log().has_method("get_entries"):
		restored_entry_count = _event_log().get_entries().size()
	var expected_entry_count := int(log_cursor.get("entry_count", restored_entry_count))
	if expected_entry_count != restored_entry_count:
		return _snapshot_result(false, SNAPSHOT_ERROR_LOG_CURSOR_MISMATCH, {
			"expected_entry_count": expected_entry_count,
			"restored_entry_count": restored_entry_count,
		})
	var expected_last_entry_id := str(log_cursor.get("last_entry_id", ""))
	if expected_last_entry_id != "":
		var restored_entries: Array = _event_log().get_entries() if _event_log() != null and _event_log().has_method("get_entries") else []
		var actual_last_entry_id := ""
		if not restored_entries.is_empty():
			actual_last_entry_id = str(restored_entries[restored_entries.size() - 1].get("entry_id", ""))
		if expected_last_entry_id != actual_last_entry_id:
			return _snapshot_result(false, SNAPSHOT_ERROR_LOG_CURSOR_MISMATCH, {
				"expected_last_entry_id": expected_last_entry_id,
				"actual_last_entry_id": actual_last_entry_id,
			})

	_run_state().set_phase(&"ready")
	return _snapshot_result(true, SNAPSHOT_ERROR_OK, {
		"seed": _seed,
		"mode": str(snapshot_mode),
		"day": restored_day,
		"minute_of_day": restored_minute,
		"entry_count": restored_entry_count,
	})


func advance_tick(hours: float) -> void:
	if hours <= 0.0:
		return
	if _catalog == null:
		bootstrap(_seed)
	if _decision_engine == null or _memory_system == null or _relationship_network == null or _behavior_library == null:
		_initialize_npc_runtime_supports()

	var previous_completed_day: int = int(_time_service().get_completed_day())
	_time_service().advance_hours(hours)
	var current_hours := float(_time_service().total_hours)
	var current_completed_day: int = int(_time_service().get_completed_day())

	for index in range(_runtime_characters.size()):
		var character: Dictionary = _runtime_characters[index]
		var character_id := StringName(str(character.get("id", "")))
		if character_id == &"":
			continue

		var npc_state := get_npc_state(character_id)
		npc_state["current_hours"] = current_hours
		var interval_hours := float(_decision_engine.get_decision_interval(npc_state))
		var last_decision_hours := float(_npc_decision_intervals.get(String(character_id), -999999.0))
		if current_hours - last_decision_hours < interval_hours:
			continue

		var decision_context := get_decision_context()
		decision_context["current_hours"] = current_hours
		var decision: Dictionary = _decision_engine.decide_action(npc_state, decision_context)
		_apply_npc_decision(index, decision, current_hours)
		_npc_decision_intervals[String(character_id)] = current_hours

	if current_completed_day > previous_completed_day:
		for day_value in range(previous_completed_day + 1, current_completed_day + 1):
			day_resolved.emit({
				"requested_hours": hours,
				"resolved_day": day_value,
				"total_minutes": _time_service().get_total_minutes(),
				"entries": _event_log().entries.size() if _event_log() != null else 0,
				"seed": _seed,
				"paused": false,
			})


func has_pending_pause() -> bool:
	return not _pending_checkpoint.is_empty()


func get_pending_checkpoint() -> Dictionary:
	return _pending_checkpoint.duplicate(true)


func advance_one_day(stop_on_pause: bool = true, auto_resolve_pause: bool = false) -> Dictionary:
	if has_pending_pause():
		if auto_resolve_pause:
			resolve_pending_checkpoint(&"auto_continue")
		elif stop_on_pause:
			return _build_pause_report(0)

	if _run_state() != null:
		_run_state().set_phase(&"simulating")
	var previous_day: int = int(_time_service().get_completed_day())
	advance_tick(24.0)
	var current_day: int = int(_time_service().get_completed_day())
	var advanced_days := maxi(0, current_day - previous_day)
	_resolved_days += advanced_days
	if _run_state() != null:
		_run_state().set_phase(&"ready")
	return {
		"requested_days": 1,
		"advanced_days": advanced_days,
		"resolved_day": current_day,
		"entry_id": "",
		"title": "hour_tick_advanced",
		"paused": false,
		"pause_title": "",
		"pause_count": _pause_count,
		"total_minutes": _time_service().get_total_minutes(),
		"entries": _event_log().entries.size() if _event_log() != null else 0,
		"seed": _seed,
	}


func get_npc_state(character_id: StringName) -> Dictionary:
	for character in _runtime_characters:
		if StringName(str(character.get("id", ""))) != character_id:
			continue
		var pressures: Dictionary = (character.get("pressures", {}) as Dictionary).duplicate(true)
		var age := int(character.get("age", 20))
		var life_stage: StringName = &"young_adult"
		if age < 18:
			life_stage = &"youth"
		elif age >= 35:
			life_stage = &"adult"
		return {
			"npc_id": character_id,
			"id": character_id,
			"realm": StringName(str(character.get("realm", "mortal"))),
			"realm_progress": float(character.get("cultivation_progress", 0.0)),
			"has_technique": bool(character.get("has_technique", false)),
			"pressures": pressures,
			"morality": float(character.get("morality", 0.0)),
			"life_stage": life_stage,
			"last_action_hours": (character.get("last_action_hours", {}) as Dictionary).duplicate(true),
		}
	return {
		"npc_id": character_id,
		"id": character_id,
		"realm": &"mortal",
		"realm_progress": 0.0,
		"has_technique": false,
		"pressures": {},
		"morality": 0.0,
		"life_stage": &"young_adult",
		"last_action_hours": {},
	}


func get_decision_context() -> Dictionary:
	return {
		"relationships": _relationship_network,
		"memory_system": _memory_system,
		"current_hours": float(_time_service().total_hours),
	}


func _apply_npc_decision(character_index: int, decision: Dictionary, current_hours: float) -> void:
	if character_index < 0 or character_index >= _runtime_characters.size():
		return
	var character: Dictionary = _runtime_characters[character_index]
	var character_id := StringName(str(character.get("id", "")))
	if character_id == &"":
		return

	var action = decision.get("action", null)
	if action == null:
		return

	var pressures: Dictionary = (character.get("pressures", {}) as Dictionary).duplicate(true)
	var total_pressure_shift := 0.0
	for pressure_key_variant in action.pressure_deltas.keys():
		var pressure_key := str(pressure_key_variant)
		var delta := float(action.pressure_deltas[pressure_key_variant])
		var previous_value := float(pressures.get(pressure_key, pressures.get(StringName(pressure_key), 0.0)))
		pressures[pressure_key] = clampf(previous_value + delta, 0.0, 100.0)
		total_pressure_shift += absf(delta)
	character["pressures"] = pressures

	var related_ids := PackedStringArray([String(character_id)])
	for relation_key_variant in action.favor_deltas.keys():
		var relation_type := StringName(str(relation_key_variant))
		var favor_delta := int(action.favor_deltas[relation_key_variant])
		var edges: Array = _relationship_network.get_edges_for(character_id)
		for edge in edges:
			if edge == null or edge.relation_type != relation_type:
				continue
			_relationship_network.modify_favor(edge.source_id, edge.target_id, favor_delta)
			if not related_ids.has(String(edge.target_id)):
				related_ids.append(String(edge.target_id))

	var last_action_hours: Dictionary = (character.get("last_action_hours", {}) as Dictionary).duplicate(true)
	last_action_hours[String(action.action_id)] = current_hours
	character["last_action_hours"] = last_action_hours
	_runtime_characters[character_index] = character

	var memory_entry := NpcMemoryEntryScript.new()
	memory_entry.event_id = StringName("npc_action_%s_%d" % [String(character_id), int(current_hours * 10.0)])
	memory_entry.event_type = StringName(str(action.action_id))
	memory_entry.timestamp_hours = current_hours
	memory_entry.importance = clampi(1 + int(total_pressure_shift), 1, 10)
	memory_entry.summary = "%s 执行了 %s" % [str(character.get("display_name", String(character_id))), str(action.label)]
	memory_entry.related_ids = related_ids
	_memory_system.add_memory(character_id, memory_entry)
	_memory_system.decay_memories(character_id, current_hours)

	if _event_log() != null:
		_event_log().add_event({
			"category": "npc_decision",
			"title": "%s 的小时决策" % str(character.get("display_name", String(character_id))),
			"actor_ids": [String(character_id)],
			"related_ids": related_ids,
			"direct_cause": str(action.action_id),
			"result": "%s 选择行为：%s（%s）。" % [str(character.get("display_name", String(character_id))), str(action.label), str(decision.get("reason", ""))],
			"day": _time_service().day,
			"minute_of_day": _time_service().minute_of_day,
			"trace": {
				"scores": decision.get("scores", {}),
				"current_hours": current_hours,
			},
		})


func _initialize_npc_runtime_supports() -> void:
	_world_generator = WorldGeneratorScript.new()
	_decision_engine = NpcDecisionEngineScript.new()
	_memory_system = NpcMemorySystemScript.new()
	_behavior_library = NpcBehaviorLibraryScript.new()
	if _relationship_network == null:
		_relationship_network = RelationshipNetworkScript.new()
	_npc_decision_intervals.clear()


func _decorate_snapshot_version(data: Dictionary, version: int) -> Dictionary:
	var decorated := data.duplicate(true)
	if not decorated.has("snapshot_version"):
		decorated["snapshot_version"] = version
	return decorated


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
	if _task7_enabled:
		_resolve_character_actions(simulated_day)
	var context := _build_world_event_context(simulated_day)
	var template: Resource = context.get("template", null)
	var actor: Dictionary = context.get("actor", {})
	var region: Resource = context.get("region", null)
	var faction: Resource = context.get("faction", null)
	var direct_cause: String = str(context.get("direct_cause", _pick_direct_cause(template, simulated_day)))
	var roll: int = _random.next_int(100)
	var pause_required: bool = _is_pause_required(template)
	var result: String = _build_result_text(template, actor, region, faction, direct_cause, roll, context)
	var related_ids: PackedStringArray = _build_related_ids(region, faction)
	for extra_related_id in context.get("extra_related_ids", PackedStringArray()):
		if not related_ids.has(str(extra_related_id)):
			related_ids.append(str(extra_related_id))
	var trace: Dictionary = {
		"seed": _seed,
		"template_id": str(_resource_get(template, "id", "")),
		"actor_id": str(actor.get("id", "")),
		"focus_tier": str(actor.get("focus_state", {}).get("tier", "")),
		"region_id": str(_resource_get(region, "id", "")) if region != null else "",
		"faction_id": str(_resource_get(faction, "id", "")) if faction != null else "",
		"roll": roll,
		"day": simulated_day,
		"world_rule_source": "single_shared_world_pool",
		"feedback_chain_id": str(context.get("feedback_chain_id", "shared_world_feedback")),
		"feedback_chain_window": int(context.get("feedback_chain_window", 0)),
		"feedback_stage": str(context.get("feedback_stage", "")),
		"orthodox_conflict_kind": str(context.get("orthodox_conflict_kind", "")),
		"family_id": str(context.get("family_id", "")),
		"support_faction_id": str(context.get("support_faction_id", "")),
		"observer_faction_id": str(context.get("observer_faction_id", "")),
		"conflict_target_faction_id": str(context.get("conflict_target_faction_id", "")),
		"cult_stage": str(_world_feedback_state.get("cult_stage", "faith_crowd")),
		"orthodox_hostility": int(_world_feedback_state.get("orthodox_hostility", 0)),
		"faith_activity": int(_world_feedback_state.get("faith_activity", 0)),
		"human_faith_exposure": int(_world_feedback_state.get("human_faith_exposure", 0)),
		"suppression_pressure": int(_world_feedback_state.get("suppression_pressure", 0)),
	}
	for key in context.get("trace", {}).keys():
		trace[key] = context.get("trace", {})[key]
	_remember_event_template_selection(template, simulated_day, context)
	_apply_world_feedback_after_event(template, region, faction, context)
	return _event_log().add_event({
		"category": str(_resource_get(template, "event_type", "world")),
		"title": str(_resource_get(template, "display_name", "日常事件")),
		"actor_ids": [str(actor.get("id", ""))],
		"related_ids": related_ids,
		"direct_cause": direct_cause,
		"result": result,
		"pause_required": pause_required,
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": trace,
	})


func _resolve_human_mode_day(simulated_day: int) -> void:
	if _human_runtime.is_empty():
		return
	var resolution: Dictionary = _human_mode_runtime.advance_day(_human_runtime, simulated_day)
	_human_runtime = resolution.get("runtime", _human_runtime).duplicate(true)
	var player: Dictionary = _human_runtime.get("player", {})
	var pressures: Dictionary = _human_runtime.get("pressures", {})
	var cultivation_gate: Dictionary = _human_runtime.get("cultivation_gate", {})
	var cultivation_state: Dictionary = _human_runtime.get("cultivation_state", {})
	var action: Dictionary = resolution.get("action", {})
	var cultivation: Dictionary = resolution.get("cultivation", {})
	var movement: Dictionary = _resolve_human_action_movement(simulated_day, player, action)
	if bool(movement.get("moved", false)):
		player = _human_runtime.get("player", {}).duplicate(true)
	if bool(resolution.get("death_triggered", false)):
		_log_human_death_resolution(simulated_day, resolution)
		if bool(resolution.get("termination_triggered", false)):
			return
	if bool(_human_runtime.get("lineage", {}).get("terminated", false)):
		return
	_event_log().add_event({
		"category": "human_action",
		"title": "%s 的凡俗抉择" % str(player.get("display_name", "主角")),
		"actor_ids": [str(player.get("id", "human_player"))],
		"related_ids": [
			str(player.get("region_id", "")),
			str(player.get("family_id", "")),
			str(player.get("sect_id", "")),
		],
		"direct_cause": str(action.get("action_id", "human_daily_action")),
		"result": "%s 选择了%s，当前主线偏向 %s。" % [
			str(player.get("display_name", "主角")),
			str(action.get("label", "凡俗行动")),
			str(_human_runtime.get("dominant_branch", "survival")),
		],
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"opening_type": str(_human_runtime.get("opening_type", "")),
			"dominant_branch": str(_human_runtime.get("dominant_branch", "")),
			"survival_pressure": int(pressures.get("survival", 0)),
			"family_pressure": int(pressures.get("family", 0)),
			"learning_pressure": int(pressures.get("learning", 0)),
			"cultivation_pressure": int(pressures.get("cultivation", 0)),
			"cultivation_contact_score": int(cultivation_gate.get("contact_score", 0)),
			"cultivation_opportunity_unlocked": bool(cultivation_gate.get("opportunity_unlocked", false)),
			"cultivation_realm": str(cultivation_state.get("realm", "mortal")),
			"cultivation_stage_label": str(cultivation_state.get("realm_label", "凡体")),
			"cultivation_stage_index": int(cultivation_state.get("stage_index", 0)),
			"cultivation_progress": int(cultivation_state.get("progress", 0)),
			"cultivation_progress_to_next": int(cultivation_state.get("progress_to_next", 0)),
			"cultivation_practice_days": int(cultivation_state.get("practice_days", 0)),
			"cultivation_weakness_days": int(cultivation_state.get("weakness_days", 0)),
			"cultivation_setback_count": int(cultivation_state.get("setback_count", 0)),
			"cultivation_lifespan_remaining_years": int(cultivation_state.get("lifespan_remaining_years", 0)),
			"cultivation_last_breakthrough": str(cultivation_state.get("last_breakthrough_outcome", "")),
			"faith_contact_score": int(cultivation_gate.get("faith_contact_score", 0)),
			"orthodox_suspicion": int(cultivation_gate.get("orthodox_suspicion", 0)),
			"faith_marked": bool(cultivation_gate.get("faith_marked", false)),
			"recent_action": str(action.get("action_id", "")),
		},
	})
	if bool(resolution.get("unlocked_now", false)):
		_event_log().add_event({
			"category": "cultivation_opportunity",
			"title": "%s 接近灵根测试门槛" % str(player.get("display_name", "主角")),
			"actor_ids": [str(player.get("id", "human_player"))],
			"related_ids": [str(player.get("sect_id", ""))],
			"direct_cause": str(action.get("action_id", "active_contact")),
			"result": "%s 因持续主动接触修仙圈层，已稳定获得灵根测试与入门机会。" % str(player.get("display_name", "主角")),
			"day": simulated_day,
			"minute_of_day": _time_service().minute_of_day,
			"trace": {
				"opening_type": str(_human_runtime.get("opening_type", "")),
				"dominant_branch": str(_human_runtime.get("dominant_branch", "")),
				"cultivation_contact_score": int(cultivation_gate.get("contact_score", 0)),
				"cultivation_opportunity_unlocked": true,
			},
		})
	if not bool(cultivation.get("blocked", true)):
		_log_human_cultivation_update(simulated_day, action, cultivation)
	if int(action.get("faith_contact_gain", 0)) > 0:
		_event_log().add_event({
			"category": "human_faith",
			"title": "%s 暗中寻神" % str(player.get("display_name", "主角")),
			"actor_ids": [str(player.get("id", "human_player"))],
			"related_ids": [str(player.get("family_id", "")), str(player.get("sect_id", ""))],
			"direct_cause": str(action.get("action_id", "faith_contact")),
			"result": "%s 因%s沾上神道线索，虽更接近神迹，却也让青岚小宗的巡察名册多记了一笔。" % [
				str(player.get("display_name", "主角")),
				str(action.get("label", "寻神之举")),
			],
			"day": simulated_day,
			"minute_of_day": _time_service().minute_of_day,
			"trace": {
				"faith_contact_gain": int(action.get("faith_contact_gain", 0)),
				"faith_contact_score": int(cultivation_gate.get("faith_contact_score", 0)),
				"orthodox_suspicion_gain": int(action.get("orthodox_suspicion_gain", 0)),
				"orthodox_suspicion": int(cultivation_gate.get("orthodox_suspicion", 0)),
				"faith_marked": bool(cultivation_gate.get("faith_marked", false)),
			},
		})
	_update_human_world_feedback()


func _resolve_deity_mode_day(simulated_day: int) -> void:
	if _deity_runtime.is_empty():
		return
	var resolution: Dictionary = _deity_mode_runtime.advance_day(_deity_runtime, simulated_day)
	_deity_runtime = resolution.get("runtime", _deity_runtime).duplicate(true)
	var deity: Dictionary = _deity_runtime.get("deity", {})
	var doctrine: Dictionary = _deity_runtime.get("doctrine", {})
	var income: Dictionary = resolution.get("income", {})
	var intervention: Dictionary = resolution.get("intervention", {})
	var chosen_progress: Dictionary = resolution.get("chosen_progress", {})
	_event_log().add_event({
		"category": "deity_faith",
		"title": "%s 收拢香火" % str(deity.get("display_name", "神明")),
		"actor_ids": [str(deity.get("id", "deity_mode_actor"))],
		"related_ids": [str(doctrine.get("id", ""))],
		"direct_cause": "faith_income_tick",
		"result": _build_deity_income_result(income),
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"deity_id": str(deity.get("id", "")),
			"doctrine_id": str(doctrine.get("id", "")),
			"chosen_devotee_id": str(_deity_runtime.get("chosen_devotee", {}).get("id", "")),
			"cult_stage": str(_deity_runtime.get("cult_state", {}).get("stage", "faith_crowd")),
			"faith_current": int(_deity_runtime.get("faith", {}).get("current", 0)),
			"faith_generated_total": int(_deity_runtime.get("faith", {}).get("generated_total", 0)),
			"favored_intervention": str(_deity_runtime.get("favored_intervention", "")),
			"favored_target_tier": str(_deity_runtime.get("favored_target_tier", "")),
			"total_gain": int(income.get("total_gain", 0)),
		},
	})
	if str(intervention.get("id", "none")) == "none":
		return
	_event_log().add_event({
		"category": "deity_intervention",
		"title": "%s 发动%s" % [str(deity.get("display_name", "神明")), str(intervention.get("label", "干预"))],
		"actor_ids": [str(deity.get("id", "deity_mode_actor"))],
		"related_ids": [str(doctrine.get("id", "")), str(intervention.get("target_name", ""))],
		"direct_cause": str(intervention.get("id", "deity_intervention")),
		"result": str(intervention.get("result", "")),
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"deity_id": str(deity.get("id", "")),
			"faith_cost": int(intervention.get("cost", 0)),
			"faith_after_spend": int(intervention.get("faith_after_spend", 0)),
			"chosen_stage": str(_deity_runtime.get("chosen_devotee", {}).get("stage", "")),
			"cult_stage": str(_deity_runtime.get("cult_state", {}).get("stage", "faith_crowd")),
			"target_tier": str(intervention.get("target_tier", "")),
			"target_name": str(intervention.get("target_name", "")),
			"preferred_by_aspect": bool(intervention.get("preferred_by_aspect", false)),
		},
	})
	if bool(chosen_progress.get("has_chosen", false)):
		_event_log().add_event({
			"category": "deity_chosen",
			"title": "%s 培养主神眷者" % str(deity.get("display_name", "神明")),
			"actor_ids": [str(deity.get("id", "deity_mode_actor")), str(chosen_progress.get("devotee_id", ""))],
			"related_ids": [str(doctrine.get("id", ""))],
			"direct_cause": str(chosen_progress.get("action_id", "observe")),
			"result": str(chosen_progress.get("result", "")),
			"day": simulated_day,
			"minute_of_day": _time_service().minute_of_day,
			"trace": {
				"deity_id": str(deity.get("id", "")),
				"devotee_id": str(chosen_progress.get("devotee_id", "")),
				"devotee_name": str(chosen_progress.get("devotee_name", "")),
				"chosen_stage_before": str(chosen_progress.get("chosen_stage_before", "")),
				"chosen_stage_after": str(chosen_progress.get("chosen_stage_after", "")),
				"chosen_stage_changed": bool(chosen_progress.get("chosen_stage_changed", false)),
				"cult_stage_before": str(chosen_progress.get("cult_stage_before", "faith_crowd")),
				"cult_stage_after": str(chosen_progress.get("cult_stage_after", "faith_crowd")),
				"cult_stage_changed": bool(chosen_progress.get("cult_stage_changed", false)),
				"cult_progress": int(chosen_progress.get("cult_progress", 0)),
			},
		})
	_update_deity_world_feedback()


func _build_deity_income_result(income: Dictionary) -> String:
	var detail_parts: Array[String] = []
	var details: Dictionary = income.get("details", {})
	for tier_id in ["shallow_believer", "believer", "fervent_believer"]:
		var info: Dictionary = details.get(tier_id, {})
		detail_parts.append("%s %d 人，共 %d 点" % [
			str(info.get("label", tier_id)),
			int(info.get("count", 0)),
			int(info.get("gain", 0)),
		])
	return "%s，本日合计获得 %d 点信仰。" % ["；".join(detail_parts), int(income.get("total_gain", 0))]


func _log_human_cultivation_update(simulated_day: int, action: Dictionary, cultivation: Dictionary) -> void:
	var player: Dictionary = _human_runtime.get("player", {})
	var state: Dictionary = cultivation.get("state", {})
	var gate: Dictionary = cultivation.get("gate", {})
	var event_type := str(cultivation.get("event_type", ""))
	if event_type.is_empty():
		return
	var title := "%s 的修炼进展" % str(player.get("display_name", "主角"))
	var result := "%s 继续摸索气感。" % str(player.get("display_name", "主角"))
	match event_type:
		"enter_qi_training":
			title = "%s 踏入炼气" % str(player.get("display_name", "主角"))
			result = "%s 在机缘开启后成功引气入体，正式踏入%s。" % [str(player.get("display_name", "主角")), str(state.get("realm_label", "炼气一层"))]
		"qi_training_progress":
			result = "%s 稳定吐纳，当前%s 进度 %d/%d，余寿约 %d 年。" % [
				str(player.get("display_name", "主角")),
				str(state.get("realm_label", "炼气一层")),
				int(state.get("progress", 0)),
				int(state.get("progress_to_next", 0)),
				int(state.get("lifespan_remaining_years", 0)),
			]
		"breakthrough_failed":
			title = "%s 冲关受挫" % str(player.get("display_name", "主角"))
			result = "%s 试图更进一步却因根基未稳而冲关受挫，留下%s，余寿降至 %d 年。" % [
				str(player.get("display_name", "主角")),
				str(state.get("last_failure_reason", "气血亏虚")),
				int(state.get("lifespan_remaining_years", 0)),
			]
		"breakthrough_success":
			title = "%s 冲关成功" % str(player.get("display_name", "主角"))
			result = "%s 根基扎实，顺利突破至 %s。" % [str(player.get("display_name", "主角")), str(state.get("realm_label", "炼气二层"))]
		"recovery":
			result = "%s 因冲关余波暂缓修炼，仍在调养气血。" % str(player.get("display_name", "主角"))
		_:
			result = "%s 在机缘开启后继续尝试修炼。" % str(player.get("display_name", "主角"))
	_event_log().add_event({
		"category": "human_cultivation",
		"title": title,
		"actor_ids": [str(player.get("id", "human_player"))],
		"related_ids": [str(player.get("sect_id", ""))],
		"direct_cause": event_type,
		"result": result,
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"action_id": str(action.get("action_id", "")),
			"cultivation_realm": str(state.get("realm", "mortal")),
			"cultivation_stage_label": str(state.get("realm_label", "凡体")),
			"cultivation_stage_index": int(state.get("stage_index", 0)),
			"cultivation_progress": int(state.get("progress", 0)),
			"cultivation_progress_to_next": int(state.get("progress_to_next", 0)),
			"cultivation_practice_days": int(state.get("practice_days", 0)),
			"cultivation_weakness_days": int(state.get("weakness_days", 0)),
			"cultivation_setback_count": int(state.get("setback_count", 0)),
			"cultivation_contact_score": int(gate.get("contact_score", 0)),
			"cultivation_lifespan_remaining_years": int(state.get("lifespan_remaining_years", 0)),
			"cultivation_last_breakthrough": str(state.get("last_breakthrough_outcome", "")),
			"cultivation_failure_reason": str(state.get("last_failure_reason", "")),
			"cultivation_consequence": str(cultivation.get("consequence", "")),
		},
	})


func _log_human_death_resolution(simulated_day: int, resolution: Dictionary) -> void:
	var death_summary: Dictionary = resolution.get("death_summary", {})
	var deceased_name := str(death_summary.get("deceased_name", "主角"))
	var deceased_id := str(death_summary.get("deceased_id", "human_player"))
	var heir_name := str(death_summary.get("heir_name", ""))
	var heir_id := str(death_summary.get("heir_id", ""))
	var reason := str(death_summary.get("reason", "none"))
	if bool(resolution.get("termination_triggered", false)):
		_event_log().add_event({
			"category": "human_lineage",
			"title": "%s 身死后香火断绝" % deceased_name,
			"actor_ids": [deceased_id],
			"related_ids": [],
			"direct_cause": "human_protagonist_death",
			"result": "%s 死后未找到可承接视角的继承人，人类模式单角色视角平稳终止。" % deceased_name,
			"day": simulated_day,
			"minute_of_day": _time_service().minute_of_day,
			"trace": {
				"deceased_id": deceased_id,
				"heir_id": heir_id,
				"inheritance_reason": reason,
			},
		})
		return
	_event_log().add_event({
		"category": "human_lineage",
		"title": "%s 身死后由 %s 承继视角" % [deceased_name, heir_name],
		"actor_ids": [deceased_id, heir_id],
		"related_ids": [str(_human_runtime.get("player", {}).get("family_id", ""))],
		"direct_cause": "human_protagonist_death",
		"result": "%s 死后，由 %s 依据 %s 承继家系与单角色视角。" % [deceased_name, heir_name, reason],
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"deceased_id": deceased_id,
			"heir_id": heir_id,
			"inheritance_reason": reason,
			"used_direct_line": bool(death_summary.get("used_direct_line", false)),
			"used_legal_heir": bool(death_summary.get("used_legal_heir", false)),
		},
	})


func _build_world_event_context(simulated_day: int) -> Dictionary:
	var feedback_stage := _resolve_feedback_stage(simulated_day)
	var orthodox_conflict_kind := _resolve_orthodox_conflict_kind(feedback_stage)
	var chain_window := int((simulated_day - 1) / 3.0) + 1
	var template: Resource = _pick_event_template_for_stage(feedback_stage, simulated_day, orthodox_conflict_kind)
	var region: Resource = _pick_region_for_stage(feedback_stage, orthodox_conflict_kind)
	var support_faction: Resource = _pick_support_faction_for_stage(feedback_stage, region, orthodox_conflict_kind)
	var observer_faction: Resource = _pick_observer_faction(region, support_faction, orthodox_conflict_kind)
	var conflict_target_faction: Resource = _pick_conflict_target_faction(orthodox_conflict_kind)
	var family: Resource = _pick_active_family(feedback_stage)
	var actor: Dictionary = _pick_actor_for_context(region, support_faction)
	var direct_cause := _pick_shared_direct_cause(template, feedback_stage, region, orthodox_conflict_kind)
	var extra_related_ids: PackedStringArray = PackedStringArray()
	var family_id := str(_resource_get(family, "id", "")) if family != null else ""
	if not family_id.is_empty():
		extra_related_ids.append(family_id)
	var support_faction_id := str(_resource_get(support_faction, "id", "")) if support_faction != null else ""
	if not support_faction_id.is_empty():
		extra_related_ids.append(support_faction_id)
	var observer_faction_id := str(_resource_get(observer_faction, "id", "")) if observer_faction != null else ""
	if not observer_faction_id.is_empty() and not extra_related_ids.has(observer_faction_id):
		extra_related_ids.append(observer_faction_id)
	var conflict_target_faction_id := str(_resource_get(conflict_target_faction, "id", "")) if conflict_target_faction != null else ""
	if not conflict_target_faction_id.is_empty() and not extra_related_ids.has(conflict_target_faction_id):
		extra_related_ids.append(conflict_target_faction_id)
	return {
		"template": template,
		"region": region,
		"faction": support_faction,
		"actor": actor,
		"direct_cause": direct_cause,
		"feedback_chain_id": "shared_world_feedback",
		"feedback_chain_window": chain_window,
		"feedback_stage": feedback_stage,
		"orthodox_conflict_kind": orthodox_conflict_kind,
		"family_id": family_id,
		"support_faction_id": support_faction_id,
		"observer_faction_id": observer_faction_id,
		"conflict_target_faction_id": conflict_target_faction_id,
		"extra_related_ids": extra_related_ids,
		"trace": {
			"region_scope_tags": ",".join(_resource_get(template, "region_scope_tags", PackedStringArray())),
			"event_pool_id": str(_resource_get(region, "event_pool_id", "")) if region != null else "",
			"family_name": str(_resource_get(family, "display_name", "")) if family != null else "",
			"support_faction_name": str(_resource_get(support_faction, "display_name", "")) if support_faction != null else "",
			"observer_faction_name": str(_resource_get(observer_faction, "display_name", "")) if observer_faction != null else "",
			"conflict_target_faction_name": str(_resource_get(conflict_target_faction, "display_name", "")) if conflict_target_faction != null else "",
			"mode_gate": str(_run_state().mode) if _run_state() != null else "",
		},
	}


func _resolve_feedback_stage(simulated_day: int) -> String:
	match posmod(simulated_day - 1, 3):
		0:
			return "warning"
		1:
			return "response"
		_:
			return "aftermath"


func _pick_event_template_for_stage(feedback_stage: String, simulated_day: int, orthodox_conflict_kind: String = "") -> Resource:
	var templates: Array = _catalog.get("event_templates") if _catalog != null else []
	if templates.is_empty():
		return null
	if orthodox_conflict_kind == "investigation":
		var investigation_template: Resource = _find_event_template(ORTHODOX_INVESTIGATION_EVENT_ID)
		if investigation_template != null:
			return investigation_template
	if orthodox_conflict_kind == "suppression":
		var suppression_template: Resource = _find_event_template(ORTHODOX_SUPPRESSION_EVENT_ID)
		if suppression_template != null:
			return suppression_template
	var regular_templates: Array[Resource] = []
	for template in templates:
		if template == null:
			continue
		var template_id := str(_resource_get(template, "id", ""))
		if template_id == str(ORTHODOX_INVESTIGATION_EVENT_ID) or template_id == str(ORTHODOX_SUPPRESSION_EVENT_ID):
			continue
		regular_templates.append(template)
	if regular_templates.is_empty():
		regular_templates = templates
	var preferred_type := "festival"
	match feedback_stage:
		"warning":
			preferred_type = "disturbance"
		"response":
			preferred_type = "selection"
		_:
			preferred_type = "festival"
	var festival_saturated := feedback_stage == "aftermath" and _count_event_type_occurrences("festival", simulated_day, EVENT_TEMPLATE_FREQUENCY_WINDOW, feedback_stage) >= EVENT_TEMPLATE_FREQUENCY_CAP
	if festival_saturated:
		preferred_type = "selection"
	var candidates := _build_event_template_candidates(regular_templates, simulated_day, feedback_stage)
	if candidates.is_empty():
		return regular_templates[posmod(simulated_day - 1, regular_templates.size())]
	var has_non_festival := false
	for candidate in candidates:
		if str(candidate.get("event_type", "")) != "festival":
			has_non_festival = true
			break

	var strict_candidates: Array[Dictionary] = []
	for candidate in candidates:
		if festival_saturated and has_non_festival and str(candidate.get("event_type", "")) == "festival":
			continue
		if bool(candidate.get("in_cooldown", false)):
			continue
		if bool(candidate.get("over_frequency_cap", false)):
			continue
		strict_candidates.append(candidate)
	if not strict_candidates.is_empty():
		return _pick_best_event_template_candidate(strict_candidates, preferred_type, simulated_day)

	var cap_relaxed_candidates: Array[Dictionary] = []
	for candidate in candidates:
		if festival_saturated and has_non_festival and str(candidate.get("event_type", "")) == "festival":
			continue
		if bool(candidate.get("over_frequency_cap", false)):
			continue
		cap_relaxed_candidates.append(candidate)
	if not cap_relaxed_candidates.is_empty():
		return _pick_best_event_template_candidate(cap_relaxed_candidates, preferred_type, simulated_day)

	var cooldown_relaxed_candidates: Array[Dictionary] = []
	for candidate in candidates:
		if festival_saturated and has_non_festival and str(candidate.get("event_type", "")) == "festival":
			continue
		if bool(candidate.get("in_cooldown", false)):
			continue
		cooldown_relaxed_candidates.append(candidate)
	if not cooldown_relaxed_candidates.is_empty():
		return _pick_best_event_template_candidate(cooldown_relaxed_candidates, preferred_type, simulated_day)

	return _pick_best_event_template_candidate(candidates, preferred_type, simulated_day)


func _build_event_template_candidates(templates: Array[Resource], simulated_day: int, feedback_stage: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for template in templates:
		if template == null:
			continue
		var template_id := str(_resource_get(template, "id", ""))
		if template_id.is_empty():
			continue
		var stats := _collect_event_template_recent_stats(template_id, simulated_day, feedback_stage)
		candidates.append({
			"template": template,
			"template_id": template_id,
			"event_type": str(_resource_get(template, "event_type", "")),
			"window_count": int(stats.get("window_count", 0)),
			"diversity_count": int(stats.get("diversity_count", 0)),
			"last_day": int(stats.get("last_day", -999999)),
			"in_cooldown": bool(stats.get("in_cooldown", false)),
			"over_frequency_cap": bool(stats.get("over_frequency_cap", false)),
		})
	return candidates


func _collect_event_template_recent_stats(template_id: String, simulated_day: int, feedback_stage: String) -> Dictionary:
	var window_count := 0
	var diversity_count := 0
	var last_day := -999999
	for record in _event_template_history:
		var record_day := int(record.get("day", 0))
		if record_day <= 0 or record_day > simulated_day:
			continue
		if str(record.get("feedback_stage", "")) != feedback_stage:
			continue
		if str(record.get("template_id", "")) != template_id:
			continue
		if simulated_day - record_day < EVENT_TEMPLATE_FREQUENCY_WINDOW:
			window_count += 1
		if simulated_day - record_day < EVENT_TEMPLATE_DIVERSITY_WINDOW:
			diversity_count += 1
		if record_day > last_day:
			last_day = record_day
	return {
		"window_count": window_count,
		"diversity_count": diversity_count,
		"last_day": last_day,
		"in_cooldown": simulated_day - last_day <= EVENT_TEMPLATE_COOLDOWN_DAYS,
		"over_frequency_cap": window_count >= EVENT_TEMPLATE_FREQUENCY_CAP,
	}


func _pick_best_event_template_candidate(candidates: Array[Dictionary], preferred_type: String, simulated_day: int) -> Resource:
	if candidates.is_empty():
		return null
	var selected_candidate: Dictionary = candidates[0]
	var selected_score := _score_event_template_candidate(selected_candidate, preferred_type, simulated_day)
	for index in range(1, candidates.size()):
		var candidate := candidates[index]
		var candidate_score := _score_event_template_candidate(candidate, preferred_type, simulated_day)
		if candidate_score < selected_score:
			selected_candidate = candidate
			selected_score = candidate_score
	return selected_candidate.get("template", null)


func _score_event_template_candidate(candidate: Dictionary, preferred_type: String, simulated_day: int) -> int:
	var window_count := int(candidate.get("window_count", 0))
	var diversity_count := int(candidate.get("diversity_count", 0))
	var last_day := int(candidate.get("last_day", -999999))
	var event_type := str(candidate.get("event_type", ""))
	var template_id := str(candidate.get("template_id", ""))
	var type_penalty := 0 if event_type == preferred_type else 1
	var recency_penalty := simulated_day - last_day
	if last_day <= -999999:
		recency_penalty = 999999
	var tie_breaker := posmod(hash(template_id) + simulated_day * 17, 97)
	return window_count * 100000 + diversity_count * 1000 + type_penalty * 100 + recency_penalty + tie_breaker


func _remember_event_template_selection(template: Resource, simulated_day: int, context: Dictionary) -> void:
	if template == null:
		return
	var template_id := str(_resource_get(template, "id", ""))
	if template_id.is_empty():
		return
	_event_template_history.append({
		"template_id": template_id,
		"event_type": str(_resource_get(template, "event_type", "")),
		"day": simulated_day,
		"feedback_stage": str(context.get("feedback_stage", "")),
		"orthodox_conflict_kind": str(context.get("orthodox_conflict_kind", "")),
	})


func _count_event_type_occurrences(event_type: String, simulated_day: int, window_size: int, feedback_stage: String = "") -> int:
	if event_type.is_empty() or window_size <= 0:
		return 0
	var count := 0
	for record in _event_template_history:
		var record_day := int(record.get("day", 0))
		if record_day <= 0 or record_day > simulated_day:
			continue
		if not feedback_stage.is_empty() and str(record.get("feedback_stage", "")) != feedback_stage:
			continue
		if simulated_day - record_day >= window_size:
			continue
		if str(record.get("event_type", "")) == event_type:
			count += 1
	return count


func _prune_event_template_history(simulated_day: int) -> void:
	if _event_template_history.is_empty():
		return
	var keep_window := maxi(EVENT_TEMPLATE_DIVERSITY_WINDOW, EVENT_TEMPLATE_FREQUENCY_WINDOW) + EVENT_TEMPLATE_COOLDOWN_DAYS + 2
	var cutoff_day := simulated_day - keep_window
	var trimmed: Array[Dictionary] = []
	for record in _event_template_history:
		if int(record.get("day", 0)) >= cutoff_day:
			trimmed.append(record)
	_event_template_history = trimmed


func _pick_region_for_stage(feedback_stage: String, orthodox_conflict_kind: String = "") -> Resource:
	if _catalog == null:
		return null
	if not orthodox_conflict_kind.is_empty():
		return _pick_orthodox_conflict_region()
	var target_region_id := "mvp_village_region"
	match feedback_stage:
		"warning":
			if int(_world_feedback_state.get("cult_presence", 0)) >= 3 and int(_world_feedback_state.get("secret_realm_heat", 0)) >= int(_world_feedback_state.get("ghost_pressure", 0)):
				target_region_id = "mvp_secret_realm_gate_region"
			elif int(_world_feedback_state.get("ghost_pressure", 0)) > int(_world_feedback_state.get("beast_pressure", 0)):
				target_region_id = "mvp_ghost_ruins_region"
			else:
				target_region_id = "mvp_beast_ridge_region"
		"response":
			if int(_world_feedback_state.get("sect_interest", 0)) >= int(_world_feedback_state.get("cult_presence", 0)):
				target_region_id = "mvp_sect_mountain_region" if bool(_world_feedback_state.get("cultivation_opportunity_unlocked", false)) else "mvp_village_region"
			else:
				target_region_id = "mvp_small_city_region"
		_:
			target_region_id = "mvp_small_city_region" if int(_world_feedback_state.get("city_alert", 0)) >= int(_world_feedback_state.get("family_pressure", 0)) else "mvp_village_region"
	return _catalog.find_region(StringName(target_region_id))


func _pick_support_faction_for_stage(feedback_stage: String, region: Resource, orthodox_conflict_kind: String = "") -> Resource:
	if _catalog == null:
		return null
	if not orthodox_conflict_kind.is_empty():
		return _catalog.find_faction(&"mvp_small_sect")
	var region_id := str(_resource_get(region, "id", "")) if region != null else ""
	var target_faction_id := str(_resource_get(region, "controlling_faction_id", "")) if region != null else ""
	match feedback_stage:
		"warning":
			if region_id == "mvp_beast_ridge_region":
				target_faction_id = "mvp_small_sect"
			elif region_id == "mvp_ghost_ruins_region":
				target_faction_id = "mvp_small_city"
			elif region_id == "mvp_secret_realm_gate_region":
				target_faction_id = "mvp_divine_cult"
		"response":
			if int(_world_feedback_state.get("sect_interest", 0)) >= int(_world_feedback_state.get("cult_presence", 0)):
				target_faction_id = "mvp_small_sect"
			else:
				target_faction_id = "mvp_divine_cult"
		_:
			if region_id == "mvp_small_city_region":
				target_faction_id = "mvp_small_city"
			else:
				target_faction_id = "mvp_village_settlement"
	return _catalog.find_faction(StringName(target_faction_id))


func _pick_observer_faction(region: Resource, support_faction: Resource, orthodox_conflict_kind: String = "") -> Resource:
	if _catalog == null:
		return null
	var support_id := str(_resource_get(support_faction, "id", "")) if support_faction != null else ""
	if not orthodox_conflict_kind.is_empty() and support_id == "mvp_small_sect":
		return _catalog.find_faction(&"mvp_small_city")
	if support_id == "mvp_small_sect":
		return _catalog.find_faction(&"mvp_small_city")
	if support_id == "mvp_divine_cult":
		return _catalog.find_faction(&"mvp_small_city")
	var region_id := str(_resource_get(region, "id", "")) if region != null else ""
	if region_id == "mvp_village_region":
		return _catalog.find_faction(&"mvp_small_sect")
	if region_id == "mvp_ghost_ruins_region":
		return _catalog.find_faction(&"mvp_small_sect")
	return _catalog.find_faction(&"mvp_divine_cult")


func _pick_active_family(feedback_stage: String) -> Resource:
	if _catalog == null:
		return null
	var family_id := str(_world_feedback_state.get("active_family_id", ""))
	if family_id.is_empty() and feedback_stage == "response" and int(_world_feedback_state.get("cult_presence", 0)) > int(_world_feedback_state.get("family_pressure", 0)):
		family_id = "mvp_shen_family"
	if family_id.is_empty():
		family_id = "mvp_lin_family"
	return _catalog.find_family(StringName(family_id))


func _pick_actor_for_context(region: Resource, faction: Resource) -> Dictionary:
	var preferred_ids: PackedStringArray = PackedStringArray()
	if not _human_runtime.is_empty():
		preferred_ids.append(str(_human_runtime.get("player", {}).get("id", "")))
	if not _deity_runtime.is_empty():
		preferred_ids.append(str(_deity_runtime.get("chosen_devotee", {}).get("id", "")))
	var region_id := str(_resource_get(region, "id", "")) if region != null else ""
	var faction_id := str(_resource_get(faction, "id", "")) if faction != null else ""
	for preferred_id in preferred_ids:
		if preferred_id.is_empty():
			continue
		for character in _runtime_characters:
			if str(character.get("id", "")) != preferred_id:
				continue
			return character.duplicate(true)
	for character in _runtime_characters:
		if str(character.get("region_id", "")) == region_id:
			return character.duplicate(true)
	for character in _runtime_characters:
		if str(character.get("faction_id", "")) == faction_id:
			return character.duplicate(true)
	return _pick_actor()


func _pick_shared_direct_cause(template: Resource, feedback_stage: String, region: Resource, orthodox_conflict_kind: String = "") -> String:
	var base_cause := _pick_direct_cause(template, _time_service().get_completed_day() + 1)
	var region_id := str(_resource_get(region, "id", "")) if region != null else ""
	if orthodox_conflict_kind == "investigation":
		return "orthodox_faith_investigation"
	if orthodox_conflict_kind == "suppression":
		return "orthodox_faith_suppression"
	if feedback_stage == "warning":
		if region_id == "mvp_beast_ridge_region":
			return "beast_pressure"
		if region_id == "mvp_ghost_ruins_region":
			return "ghost_presence"
		if region_id == "mvp_secret_realm_gate_region":
			return "secret_realm_omen"
	if feedback_stage == "response":
		return "faction_response_%s" % str(_resource_get(template, "event_type", base_cause))
	return base_cause


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


func _build_result_text(template: Resource, actor: Dictionary, region: Resource, faction: Resource, direct_cause: String, roll: int, context: Dictionary = {}) -> String:
	var actor_name := str(actor.get("display_name", "无名氏"))
	var region_name := str(_resource_get(region, "display_name", "无名地带")) if region != null else "无名地带"
	var faction_name := str(_resource_get(faction, "display_name", "无归属势力")) if faction != null else "无归属势力"
	var title := str(_resource_get(template, "display_name", "日常事件")) if template != null else "日常事件"
	var feedback_stage := str(context.get("feedback_stage", ""))
	var orthodox_conflict_kind := str(context.get("orthodox_conflict_kind", ""))
	var family: Resource = _catalog.find_family(StringName(str(context.get("family_id", "")))) if _catalog != null and not str(context.get("family_id", "")).is_empty() else null
	var family_name := str(_resource_get(family, "display_name", "乡里家族")) if family != null else "乡里家族"
	var observer_faction: Resource = _catalog.find_faction(StringName(str(context.get("observer_faction_id", "")))) if _catalog != null and not str(context.get("observer_faction_id", "")).is_empty() else null
	var observer_name := str(_resource_get(observer_faction, "display_name", "旁观势力")) if observer_faction != null else "旁观势力"
	var conflict_target_faction: Resource = _catalog.find_faction(StringName(str(context.get("conflict_target_faction_id", "")))) if _catalog != null and not str(context.get("conflict_target_faction_id", "")).is_empty() else null
	var conflict_target_name := str(_resource_get(conflict_target_faction, "display_name", actor_name)) if conflict_target_faction != null else actor_name
	if orthodox_conflict_kind == "investigation":
		return "%s 在 %s 借%s追查异端香火，%s 因近来寻神传闻被列入巡察册，%s 也开始留意 %s 的动向。" % [
			faction_name,
			region_name,
			title,
			actor_name,
			observer_name,
			conflict_target_name,
		]
	if orthodox_conflict_kind == "suppression":
		return "%s 在 %s 借%s公开镇压神道线索，%s 与 %s 的牵连被当众点破，先前主动寻神或传谕的代价彻底浮出水面。" % [
			faction_name,
			region_name,
			title,
			actor_name,
			conflict_target_name,
		]
	if feedback_stage == "warning":
		if direct_cause == "beast_pressure":
			return "%s 在 %s 引发%s，%s 因采路受扰向 %s 求援，%s 也开始整理沿线传闻。" % [actor_name, region_name, title, family_name, faction_name, observer_name]
		if direct_cause == "ghost_presence":
			return "%s 在 %s 撞见%s余波，%s 被卷入失踪怪谈，%s 与 %s 同步异变消息。" % [actor_name, region_name, title, family_name, faction_name, observer_name]
		if direct_cause == "secret_realm_omen":
			return "%s 在 %s 遇到%s，%s 借异兆吸引边缘香火，%s 也把消息带回 %s。" % [actor_name, region_name, title, faction_name, actor_name, family_name]
	if feedback_stage == "response":
		if str(_resource_get(template, "event_type", "")) == "selection" and str(_resource_get(faction, "id", "")) == "mvp_small_sect":
			return "%s 借 %s 在 %s 筛选可塑之人，%s 因前日求援被列入观察，%s 顺势稳住乡里秩序。" % [faction_name, title, region_name, actor_name, family_name]
		if str(_resource_get(faction, "id", "")) == "mvp_divine_cult":
			return "%s 借 %s 在 %s 吸纳边缘人，%s 所在的 %s 前去观望，%s 开始记录这股新风声。" % [faction_name, title, region_name, actor_name, family_name, observer_name]
	if feedback_stage == "aftermath":
		var aftermath_outcome_variants: Array[String] = [
			"使后续往来更频繁",
			"让多方都开始重新评估立场",
			"让同一套世界规则留下了连续回响",
		]
		var outcome_text: String = aftermath_outcome_variants[roll % aftermath_outcome_variants.size()]
		return "%s 在 %s 见证%s的余波，%s、%s 与 %s 的联系被进一步拉紧，%s。" % [actor_name, region_name, title, family_name, faction_name, observer_name, outcome_text]
	var outcome_variants: Array[String] = [
		"获得了稳定反馈",
		"引起了周围人的注意",
		"让后续选择变得更明确",
	]
	var outcome_text: String = outcome_variants[roll % outcome_variants.size()]
	return "%s 在 %s 遭遇 %s，受 %s 驱动，与 %s 发生联系，%s。" % [actor_name, region_name, title, direct_cause, faction_name, outcome_text]


func _build_world_feedback_state() -> Dictionary:
	var state := {
		"base_values": {},
		"offset_values": {},
		"cultivation_opportunity_unlocked": bool(_human_runtime.get("cultivation_gate", {}).get("opportunity_unlocked", false)),
		"active_family_id": _resolve_initial_family_id(),
		"cult_stage": str(_deity_runtime.get("cult_state", {}).get("stage", "faith_crowd")),
	}
	_set_world_feedback_base_values_on_state(state, {
		"family_pressure": _initial_human_pressure_value(),
		"sect_interest": _initial_sect_interest_value(),
		"cult_presence": _initial_cult_presence_value(),
		"faith_activity": _initial_faith_activity_value(),
		"orthodox_hostility": _initial_orthodox_hostility_value(),
		"human_faith_exposure": _initial_human_faith_exposure_value(),
		"suppression_pressure": _initial_suppression_pressure_value(),
		"city_alert": 2,
		"beast_pressure": 3,
		"ghost_pressure": 2,
		"secret_realm_heat": 1,
	})
	return state


func _initial_human_pressure_value() -> int:
	if _human_runtime.is_empty():
		return 2
	var pressures: Dictionary = _human_runtime.get("pressures", {})
	return maxi(2, int(pressures.get("survival", 0)) + int(pressures.get("family", 0)))


func _initial_sect_interest_value() -> int:
	if _human_runtime.is_empty():
		return 2
	var gate: Dictionary = _human_runtime.get("cultivation_gate", {})
	var base_interest := 2 + int(gate.get("contact_score", 0))
	if bool(gate.get("opportunity_unlocked", false)):
		base_interest += 2
	return base_interest


func _initial_cult_presence_value() -> int:
	if _deity_runtime.is_empty():
		return 1
	var cult_state: Dictionary = _deity_runtime.get("cult_state", {})
	var stage := str(cult_state.get("stage", "faith_crowd"))
	var stage_value := 1
	if stage == "cult_nucleus":
		stage_value = 3
	elif stage == "cult_foundation":
		stage_value = 5
	return stage_value + int(cult_state.get("progress", 0))


func _initial_human_faith_exposure_value() -> int:
	if _human_runtime.is_empty():
		return 0
	var gate: Dictionary = _human_runtime.get("cultivation_gate", {})
	return int(gate.get("faith_contact_score", 0))


func _initial_faith_activity_value() -> int:
	return maxi(1, maxi(_initial_cult_presence_value(), _initial_human_faith_exposure_value()))


func _initial_orthodox_hostility_value() -> int:
	return clampi(2 + maxi(0, _initial_cult_presence_value() - 1) + mini(2, _initial_human_faith_exposure_value()), 1, 20)


func _initial_suppression_pressure_value() -> int:
	return clampi(_initial_orthodox_hostility_value() + maxi(0, _initial_faith_activity_value() - 1) - 2, 0, 20)


func _resolve_initial_family_id() -> String:
	if not _human_runtime.is_empty():
		return str(_human_runtime.get("player", {}).get("family_id", ""))
	if not _deity_runtime.is_empty():
		return str(_deity_runtime.get("chosen_devotee", {}).get("family_id", ""))
	return "mvp_lin_family"


func _update_human_world_feedback() -> void:
	if _human_runtime.is_empty():
		return
	var pressures: Dictionary = _human_runtime.get("pressures", {})
	var gate: Dictionary = _human_runtime.get("cultivation_gate", {})
	_set_world_feedback_base_values({
		"family_pressure": int(pressures.get("survival", 0)) + int(pressures.get("family", 0)),
		"sect_interest": 2 + int(gate.get("contact_score", 0)) + (3 if bool(gate.get("opportunity_unlocked", false)) else 0),
		"human_faith_exposure": int(gate.get("faith_contact_score", 0)),
		"faith_activity": maxi(1, int(gate.get("faith_contact_score", 0)) + (1 if bool(gate.get("faith_marked", false)) else 0)),
		"orthodox_hostility": 2 + int(gate.get("orthodox_suspicion", 0)) + (2 if bool(gate.get("faith_marked", false)) else 0),
		"suppression_pressure": int(_world_feedback_state.get("orthodox_hostility", 0)) + int(gate.get("faith_contact_score", 0)) - 2,
	})
	_world_feedback_state["cultivation_opportunity_unlocked"] = bool(gate.get("opportunity_unlocked", false))
	_world_feedback_state["active_family_id"] = str(_human_runtime.get("player", {}).get("family_id", _world_feedback_state.get("active_family_id", "mvp_lin_family")))


func _update_deity_world_feedback() -> void:
	if _deity_runtime.is_empty():
		return
	var cult_state: Dictionary = _deity_runtime.get("cult_state", {})
	var stage := str(cult_state.get("stage", "faith_crowd"))
	var stage_value := 1
	if stage == "cult_nucleus":
		stage_value = 3
	elif stage == "cult_foundation":
		stage_value = 5
	var cult_presence := stage_value + int(cult_state.get("progress", 0))
	_set_world_feedback_base_values({
		"cult_presence": cult_presence,
		"faith_activity": cult_presence + (1 if stage != "faith_crowd" else 0),
		"orthodox_hostility": 2 + cult_presence + (2 if stage == "cult_foundation" else 1 if stage == "cult_nucleus" else 0),
		"suppression_pressure": int(_world_feedback_state.get("orthodox_hostility", 0)) + int(cult_state.get("progress", 0)) - 2,
		"human_faith_exposure": 0,
		"secret_realm_heat": 1 + int(cult_state.get("progress", 0)) + stage_value,
		"city_alert": 2 + int(cult_state.get("progress", 0)) + (1 if stage != "faith_crowd" else 0),
	})
	_world_feedback_state["cult_stage"] = stage
	var chosen_devotee: Dictionary = _deity_runtime.get("chosen_devotee", {})
	if not chosen_devotee.is_empty():
		_world_feedback_state["active_family_id"] = str(chosen_devotee.get("family_id", _world_feedback_state.get("active_family_id", "mvp_shen_family")))


func _apply_world_feedback_after_event(template: Resource, region: Resource, faction: Resource, context: Dictionary) -> void:
	var feedback_stage := str(context.get("feedback_stage", ""))
	var orthodox_conflict_kind := str(context.get("orthodox_conflict_kind", ""))
	var event_type := str(_resource_get(template, "event_type", "world"))
	var region_id := str(_resource_get(region, "id", "")) if region != null else ""
	if orthodox_conflict_kind == "investigation":
		_adjust_world_feedback_offset("orthodox_hostility", 1)
		_adjust_world_feedback_offset("suppression_pressure", 1)
		_adjust_world_feedback_offset("city_alert", 1)
		return
	if orthodox_conflict_kind == "suppression":
		_adjust_world_feedback_offset("faith_activity", -1)
		_adjust_world_feedback_offset("human_faith_exposure", -1)
		_adjust_world_feedback_offset("cult_presence", -1)
		_adjust_world_feedback_offset("family_pressure", 1)
		_adjust_world_feedback_offset("city_alert", 1)
		return
	if feedback_stage == "warning":
		if region_id == "mvp_beast_ridge_region":
			_adjust_world_feedback_offset("beast_pressure", 1)
			_adjust_world_feedback_offset("sect_interest", 1)
		elif region_id == "mvp_ghost_ruins_region":
			_adjust_world_feedback_offset("ghost_pressure", 1)
			_adjust_world_feedback_offset("city_alert", 1)
		elif region_id == "mvp_secret_realm_gate_region":
			_adjust_world_feedback_offset("secret_realm_heat", 1)
			_adjust_world_feedback_offset("cult_presence", 1)
	elif feedback_stage == "response":
		if event_type == "selection" and str(_resource_get(faction, "id", "")) == "mvp_small_sect":
			_adjust_world_feedback_offset("family_pressure", -1)
			_adjust_world_feedback_offset("sect_interest", 1)
		elif str(_resource_get(faction, "id", "")) == "mvp_divine_cult":
			_adjust_world_feedback_offset("cult_presence", 1)
			_adjust_world_feedback_offset("city_alert", 1)
	else:
		_adjust_world_feedback_offset("beast_pressure", -1)
		_adjust_world_feedback_offset("ghost_pressure", -1)


func _set_world_feedback_base_values(base_updates: Dictionary) -> void:
	_set_world_feedback_base_values_on_state(_world_feedback_state, base_updates)


func _set_world_feedback_base_values_on_state(state: Dictionary, base_updates: Dictionary) -> void:
	var base_values: Dictionary = (state.get("base_values", {}) as Dictionary).duplicate(true)
	for key in base_updates.keys():
		base_values[key] = int(base_updates.get(key, 0))
	state["base_values"] = base_values
	_recompute_world_feedback_values(state)


func _adjust_world_feedback_offset(key: String, delta: int) -> void:
	if not WORLD_FEEDBACK_NUMERIC_LIMITS.has(key):
		return
	var offset_values: Dictionary = (_world_feedback_state.get("offset_values", {}) as Dictionary).duplicate(true)
	offset_values[key] = int(offset_values.get(key, 0)) + delta
	_world_feedback_state["offset_values"] = offset_values
	_recompute_world_feedback_values(_world_feedback_state)


func _recompute_world_feedback_values(state: Dictionary) -> void:
	var base_values: Dictionary = state.get("base_values", {})
	var offset_values: Dictionary = state.get("offset_values", {})
	for key in WORLD_FEEDBACK_NUMERIC_LIMITS.keys():
		var limits: Dictionary = WORLD_FEEDBACK_NUMERIC_LIMITS[key]
		state[key] = clampi(
			int(base_values.get(key, 0)) + int(offset_values.get(key, 0)),
			int(limits.get("min", 0)),
			int(limits.get("max", 20))
		)


func _resolve_orthodox_conflict_kind(feedback_stage: String) -> String:
	var orthodox_hostility := int(_world_feedback_state.get("orthodox_hostility", 0))
	var faith_activity := int(_world_feedback_state.get("faith_activity", 0))
	var suppression_pressure := int(_world_feedback_state.get("suppression_pressure", 0))
	if feedback_stage == "warning" and orthodox_hostility >= 3 and faith_activity >= 2:
		return "investigation"
	if feedback_stage == "response" and orthodox_hostility >= 5 and maxi(faith_activity, suppression_pressure) >= 4:
		return "suppression"
	return ""


func _pick_orthodox_conflict_region() -> Resource:
	if _catalog == null:
		return null
	var chosen_region_id := str(_deity_runtime.get("chosen_devotee", {}).get("region_id", ""))
	if chosen_region_id.is_empty():
		chosen_region_id = str(_human_runtime.get("player", {}).get("region_id", ""))
	if chosen_region_id.is_empty():
		chosen_region_id = "mvp_small_city_region"
	return _catalog.find_region(StringName(chosen_region_id))


func _pick_conflict_target_faction(orthodox_conflict_kind: String) -> Resource:
	if orthodox_conflict_kind.is_empty() or _catalog == null:
		return null
	if not _deity_runtime.is_empty() and str(_deity_runtime.get("cult_state", {}).get("stage", "faith_crowd")) != "faith_crowd":
		return _catalog.find_faction(&"mvp_divine_cult")
	return null


func _find_event_template(event_template_id: StringName) -> Resource:
	if _catalog == null or not _catalog.has_method("find_event_template"):
		return null
	return _catalog.find_event_template(event_template_id)


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
		var runtime_character := {
			"id": str(_resource_get(character, "id", "")),
			"display_name": str(_resource_get(character, "display_name", "")),
			"summary": str(_resource_get(character, "summary", "")),
			"tags": _resource_get(character, "tags", PackedStringArray()),
			"region_id": str(_resource_get(character, "region_id", "")),
			"faction_id": str(_resource_get(character, "faction_id", "")),
			"family_id": str(_resource_get(character, "family_id", "")),
			"talent_rank": int(_resource_get(character, "talent_rank", 0)),
			"faith_affinity": int(_resource_get(character, "faith_affinity", 0)),
			"morality_tags": _resource_get(character, "morality_tags", PackedStringArray()),
			"temperament_tags": _resource_get(character, "temperament_tags", PackedStringArray()),
			"role_tags": _resource_get(character, "role_tags", PackedStringArray()),
			"life_goal_summary": str(_resource_get(character, "life_goal_summary", "")),
		}
		runtime_character["morality_profile"] = _build_morality_profile(runtime_character)
		runtime_character["focus_state"] = _build_focus_state(runtime_character)
		runtime_character["need_scores"] = _build_initial_need_scores(runtime_character)
		runtime_character["dominant_need"] = _select_dominant_need(runtime_character["need_scores"])
		runtime_character["active_goal"] = _build_active_goal(runtime_character)
		runtime_character["last_action"] = {
			"intent": "idle",
			"method": "observe",
			"day": 0,
		}
		characters.append(runtime_character)
	return characters


func _build_human_runtime() -> Dictionary:
	if _run_state() == null or _run_state().mode != &"human":
		return {}
	if _catalog == null:
		return {}
	return _human_mode_runtime.build_initial_state(_catalog, _human_mode_options)


func _build_deity_runtime() -> Dictionary:
	if _run_state() == null or _run_state().mode != &"deity":
		return {}
	if _catalog == null:
		return {}
	return _deity_mode_runtime.build_initial_state(_catalog, _runtime_characters, _deity_mode_options)


func _resolve_character_actions(simulated_day: int) -> void:
	for index in range(_runtime_characters.size()):
		var character: Dictionary = _runtime_characters[index]
		if not _is_character_update_due(character, simulated_day):
			continue
		var focus_state: Dictionary = character.get("focus_state", {})
		var stride_days := maxi(1, int(focus_state.get("stride_days", 1)))
		var detail_level := "detailed" if str(focus_state.get("tier", "background")) == "focused" else "summary"
		var need_scores: Dictionary = character.get("need_scores", {}).duplicate(true)
		_apply_need_drift(character, need_scores, stride_days)
		character["need_scores"] = need_scores
		character["dominant_need"] = _select_dominant_need(need_scores)
		character["active_goal"] = _build_active_goal(character)
		var intent := _build_action_intent(character)
		var method := _pick_action_method(character, intent)
		var movement := _resolve_npc_action_movement(simulated_day, character, intent)
		if bool(movement.get("moved", false)):
			character["region_id"] = str(movement.get("to_region_id", character.get("region_id", "")))
		character["last_action"] = {
			"intent": intent,
			"method": method,
			"day": simulated_day,
		}
		focus_state["last_update_day"] = simulated_day
		if detail_level == "detailed":
			focus_state["last_detailed_day"] = simulated_day
		character["focus_state"] = focus_state
		_runtime_characters[index] = character
		_event_log().add_event(_build_character_action_entry(character, simulated_day, intent, method, detail_level))


func _is_character_update_due(character: Dictionary, simulated_day: int) -> bool:
	var focus_state: Dictionary = character.get("focus_state", {})
	var stride_days := maxi(1, int(focus_state.get("stride_days", 1)))
	var last_update_day := int(focus_state.get("last_update_day", 0))
	return simulated_day - last_update_day >= stride_days


func _apply_need_drift(character: Dictionary, need_scores: Dictionary, step_days: int) -> void:
	var role_tags: PackedStringArray = character.get("role_tags", PackedStringArray())
	var faith_affinity := int(character.get("faith_affinity", 0))
	var talent_rank := int(character.get("talent_rank", 0))
	need_scores[NEED_RESOURCE] = int(need_scores.get(NEED_RESOURCE, 0)) + step_days * (2 if role_tags.has("resource_seeker") else 1)
	need_scores[NEED_STABILITY] = int(need_scores.get(NEED_STABILITY, 0)) + step_days * (2 if role_tags.has("guardian") else 1)
	need_scores[NEED_REPUTATION] = int(need_scores.get(NEED_REPUTATION, 0)) + step_days * (1 + maxi(0, talent_rank - 1))
	need_scores[NEED_BELONGING] = int(need_scores.get(NEED_BELONGING, 0)) + step_days * (2 if faith_affinity >= 3 else 1)


func _build_character_action_entry(character: Dictionary, simulated_day: int, intent: String, method: String, detail_level: String) -> Dictionary:
	var morality_profile: Dictionary = character.get("morality_profile", {})
	var active_goal: Dictionary = character.get("active_goal", {})
	var dominant_need := str(character.get("dominant_need", ""))
	var actor_id := str(character.get("id", ""))
	var actor_name := str(character.get("display_name", "无名氏"))
	return {
		"category": "npc_action",
		"title": "%s 采取行动" % actor_name,
		"actor_ids": [actor_id],
		"direct_cause": "task7_npc_intent",
		"result": _build_character_action_text(character, intent, method, detail_level),
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"actor_id": actor_id,
			"need_key": dominant_need,
			"goal_id": str(active_goal.get("id", "")),
			"intent": intent,
			"method": method,
			"morality_style": str(morality_profile.get("style", "neutral")),
			"focus_tier": str(character.get("focus_state", {}).get("tier", "background")),
			"detail_level": detail_level,
		},
	}


func _build_character_action_text(character: Dictionary, intent: String, method: String, detail_level: String) -> String:
	var actor_name := str(character.get("display_name", "无名氏"))
	var active_goal: Dictionary = character.get("active_goal", {})
	var goal_summary := str(active_goal.get("summary", "维持当前处境"))
	if detail_level == "detailed":
		return "%s 因 %s 转向 %s，并决定以 %s 落地。" % [actor_name, goal_summary, intent, method]
	return "%s 围绕 %s 进行了批量推进，手段为 %s。" % [actor_name, str(active_goal.get("direction", intent)), method]


func _build_morality_profile(character: Dictionary) -> Dictionary:
	var morality_tags: PackedStringArray = character.get("morality_tags", PackedStringArray())
	var score := 0
	var style := "neutral"
	if morality_tags.has("kind") or morality_tags.has("devout") or morality_tags.has("lawful"):
		score += 60
		style = "principled"
	if morality_tags.has("pragmatic") or morality_tags.has("patient"):
		score += 10
		if style == "neutral":
			style = "pragmatic"
	if morality_tags.has("ruthless") or morality_tags.has("cruel") or morality_tags.has("opportunistic"):
		score -= 70
		style = "ruthless"
	return {
		"score": clampi(score, -100, 100),
		"style": style,
	}


func _build_focus_state(character: Dictionary) -> Dictionary:
	var tags: PackedStringArray = character.get("tags", PackedStringArray())
	var tier := "background"
	var stride_days := 3
	if tags.has("focus_focused"):
		tier = "focused"
		stride_days = 1
	elif tags.has("focus_regular"):
		tier = "regular"
		stride_days = 2
	return {
		"tier": tier,
		"stride_days": stride_days,
		"last_update_day": 0,
		"last_detailed_day": 0,
	}


func _build_initial_need_scores(character: Dictionary) -> Dictionary:
	var role_tags: PackedStringArray = character.get("role_tags", PackedStringArray())
	var faith_affinity := int(character.get("faith_affinity", 0))
	return {
		NEED_RESOURCE: 9 if role_tags.has("resource_seeker") else 5,
		NEED_STABILITY: 8 if role_tags.has("guardian") else 4,
		NEED_REPUTATION: 6 + int(character.get("talent_rank", 0)),
		NEED_BELONGING: 5 + faith_affinity,
	}


func _select_dominant_need(need_scores: Dictionary) -> String:
	var dominant_key := ""
	var dominant_score := -999999
	for key in need_scores.keys():
		var score := int(need_scores.get(key, 0))
		if score > dominant_score:
			dominant_key = str(key)
			dominant_score = score
	return dominant_key


func _build_active_goal(character: Dictionary) -> Dictionary:
	var dominant_need := str(character.get("dominant_need", ""))
	var life_goal_summary := str(character.get("life_goal_summary", "稳住当前生活"))
	var role_tags: PackedStringArray = character.get("role_tags", PackedStringArray())
	var direction := "维持节奏"
	var goal_id := "goal_hold"
	match dominant_need:
		String(NEED_RESOURCE):
			direction = "筹措资源"
			goal_id = "goal_resource_stabilize"
		String(NEED_STABILITY):
			direction = "稳住局势"
			goal_id = "goal_secure_position"
		String(NEED_REPUTATION):
			direction = "扩大声望"
			goal_id = "goal_raise_reputation"
		String(NEED_BELONGING):
			direction = "维系关系"
			goal_id = "goal_keep_allies"
	if role_tags.has("scribe") and dominant_need == String(NEED_STABILITY):
		direction = "整理秩序"
		goal_id = "goal_order_records"
	return {
		"id": goal_id,
		"summary": life_goal_summary,
		"direction": direction,
	}


func _build_action_intent(character: Dictionary) -> String:
	var role_tags: PackedStringArray = character.get("role_tags", PackedStringArray())
	var dominant_need := str(character.get("dominant_need", ""))
	match dominant_need:
		String(NEED_RESOURCE):
			return "secure_resources"
		String(NEED_STABILITY):
			if role_tags.has("scribe"):
				return "stabilize_records"
			return "protect_position"
		String(NEED_REPUTATION):
			return "raise_reputation"
		String(NEED_BELONGING):
			return "seek_support"
		_:
			return "hold_pattern"


func _pick_action_method(character: Dictionary, intent: String) -> String:
	var morality_style := str(character.get("morality_profile", {}).get("style", "neutral"))
	match intent:
		"secure_resources":
			match morality_style:
				"principled":
					return "协商交换"
				"ruthless":
					return "强取截留"
				_:
					return "灰市周转"
		"protect_position", "stabilize_records":
			match morality_style:
				"principled":
					return "公开调解"
				"ruthless":
					return "威胁压制"
				_:
					return "私下施压"
		"raise_reputation":
			match morality_style:
				"principled":
					return "公开示范"
				"ruthless":
					return "操弄舆论"
				_:
					return "定向经营"
		"seek_support":
			match morality_style:
				"principled":
					return "求助盟友"
				"ruthless":
					return "操弄人情"
				_:
					return "试探接触"
		_:
			return "观察局势"


func _resolve_human_action_movement(simulated_day: int, player: Dictionary, action: Dictionary) -> Dictionary:
	var action_id := str(action.get("action_id", ""))
	if action_id.is_empty():
		return {"moved": false}
	var preferred_targets: Array[String] = []
	match action_id:
		"work_for_food":
			preferred_targets = ["mvp_small_city_region", "mvp_village_region"]
		"seek_master", "visit_sect", "ask_for_guidance":
			preferred_targets = ["mvp_sect_mountain_region", "mvp_small_city_region"]
		"visit_shrine", "seek_oracle":
			preferred_targets = ["mvp_small_city_region", "mvp_secret_realm_gate_region"]
		_:
			return {"moved": false}
	return _attempt_character_movement(
		str(player.get("id", "human_player")),
		str(player.get("display_name", "主角")),
		simulated_day,
		action_id,
		preferred_targets,
	)


func _resolve_npc_action_movement(simulated_day: int, character: Dictionary, intent: String) -> Dictionary:
	var preferred_targets: Array[String] = []
	match intent:
		"seek_support":
			preferred_targets = ["mvp_small_city_region", "mvp_village_region"]
		"secure_resources":
			preferred_targets = ["mvp_small_city_region", "mvp_sect_mountain_region"]
		"raise_reputation":
			preferred_targets = ["mvp_sect_mountain_region", "mvp_small_city_region"]
		_:
			return {"moved": false}
	return _attempt_character_movement(
		str(character.get("id", "")),
		str(character.get("display_name", "无名氏")),
		simulated_day,
		"npc_%s" % intent,
		preferred_targets,
	)


func _attempt_character_movement(actor_id: String, actor_name: String, simulated_day: int, movement_cause: String, preferred_targets: Array[String]) -> Dictionary:
	if actor_id.is_empty():
		return {"moved": false}
	var location_service := _location_service()
	if location_service == null or not location_service.has_method("set_character_region"):
		return {"moved": false}
	var current_region_id := _get_runtime_character_region(actor_id)
	if location_service.has_method("get_character_region"):
		var region_from_service := str(location_service.get_character_region(StringName(actor_id)))
		if not region_from_service.is_empty():
			current_region_id = region_from_service
	if current_region_id.is_empty():
		return {"moved": false}
	var target_region_id := _pick_adjacent_movement_target(current_region_id, preferred_targets)
	if target_region_id.is_empty() or target_region_id == current_region_id:
		return {"moved": false}
	var move_result: Dictionary = location_service.set_character_region(StringName(actor_id), StringName(target_region_id))
	if not bool(move_result.get("ok", false)):
		return {"moved": false, "error": str(move_result.get("error", ""))}
	var context: Dictionary = move_result.get("context", {})
	if not bool(context.get("changed", false)):
		return {"moved": false}
	var from_region_id := str(context.get("from_region_id", current_region_id))
	var to_region_id := str(context.get("to_region_id", target_region_id))
	_sync_human_runtime_region(actor_id, to_region_id)
	_event_log().add_event({
		"category": "movement",
		"title": "%s 转移位置" % actor_name,
		"actor_ids": [actor_id],
		"related_ids": [from_region_id, to_region_id],
		"direct_cause": movement_cause,
		"result": "%s 从 %s 前往 %s。" % [
			actor_name,
			_region_display_name(from_region_id),
			_region_display_name(to_region_id),
		],
		"day": simulated_day,
		"minute_of_day": _time_service().minute_of_day,
		"trace": {
			"movement_from_region_id": from_region_id,
			"movement_to_region_id": to_region_id,
			"movement_cause": movement_cause,
		},
	})
	return {
		"moved": true,
		"from_region_id": from_region_id,
		"to_region_id": to_region_id,
	}


func _pick_adjacent_movement_target(current_region_id: String, preferred_targets: Array[String]) -> String:
	if _catalog == null or not _catalog.has_method("find_region"):
		return ""
	var current_region: Resource = _catalog.find_region(StringName(current_region_id))
	if current_region == null:
		return ""
	var adjacent_ids: PackedStringArray = current_region.get("adjacent_region_ids") as PackedStringArray
	for preferred in preferred_targets:
		if preferred.is_empty() or preferred == current_region_id:
			continue
		if adjacent_ids.has(preferred):
			return preferred
	if adjacent_ids.is_empty():
		return ""
	return str(adjacent_ids[0])


func _sync_human_runtime_region(character_id: String, target_region_id: String) -> void:
	if _human_runtime.is_empty() or character_id.is_empty() or target_region_id.is_empty():
		return
	var player: Dictionary = (_human_runtime.get("player", {}) as Dictionary).duplicate(true)
	if str(player.get("id", "")) == character_id:
		player["region_id"] = target_region_id
		_human_runtime["player"] = player
	var registry: Dictionary = (_human_runtime.get("character_registry", {}) as Dictionary).duplicate(true)
	if not registry.has(character_id):
		return
	var character_record: Dictionary = (registry.get(character_id, {}) as Dictionary).duplicate(true)
	character_record["region_id"] = target_region_id
	registry[character_id] = character_record
	_human_runtime["character_registry"] = registry


func _get_runtime_character_region(character_id: String) -> String:
	if character_id.is_empty():
		return ""
	for character in _runtime_characters:
		if str(character.get("id", "")) != character_id:
			continue
		return str(character.get("region_id", ""))
	return ""


func _region_display_name(region_id: String) -> String:
	if region_id.is_empty():
		return "未知地带"
	if _catalog == null or not _catalog.has_method("find_region"):
		return region_id
	var region: Resource = _catalog.find_region(StringName(region_id))
	if region == null:
		return region_id
	return str(_resource_get(region, "display_name", region_id))


func _has_task7_fixture_characters() -> bool:
	for character in _runtime_characters:
		var tags: PackedStringArray = character.get("tags", PackedStringArray())
		if tags.has("task7_ai"):
			return true
	return false


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


func _validate_snapshot_payload(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_ROOT_TYPE, {
			"reason": "empty_snapshot",
		})

	var required_fields: PackedStringArray = [
		"seed",
		"mode",
		"time",
		"runtime_characters",
		"world_feedback",
		"log_cursor",
		"event_log_entries",
	]
	for required_field in required_fields:
		if not snapshot.has(required_field):
			return _snapshot_result(false, SNAPSHOT_ERROR_MISSING_FIELD, {
				"field": required_field,
			})

	if not _is_integer_snapshot_number(snapshot.get("seed", null)):
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "seed",
			"expected": "integer number",
			"actual_type": typeof(snapshot.get("seed", null)),
		})

	if not snapshot.get("mode", "") is String:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "mode",
			"expected": "String",
			"actual_type": typeof(snapshot.get("mode", null)),
		})

	if not snapshot.get("time", null) is Dictionary:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "time",
			"expected": "Dictionary",
			"actual_type": typeof(snapshot.get("time", null)),
		})
	var time_data: Dictionary = snapshot.get("time", {})
	if not _is_integer_snapshot_number(time_data.get("day", null)):
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "time.day",
			"expected": "integer number",
			"actual_type": typeof(time_data.get("day", null)),
		})
	if not _is_integer_snapshot_number(time_data.get("minute_of_day", null)):
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "time.minute_of_day",
			"expected": "integer number",
			"actual_type": typeof(time_data.get("minute_of_day", null)),
		})

	if not snapshot.get("runtime_characters", null) is Array:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "runtime_characters",
			"expected": "Array",
			"actual_type": typeof(snapshot.get("runtime_characters", null)),
		})
	var runtime_characters_data: Array = snapshot.get("runtime_characters", [])
	for character in runtime_characters_data:
		if not character is Dictionary:
			return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
				"field": "runtime_characters[]",
				"expected": "Dictionary",
				"actual_type": typeof(character),
			})

	if not snapshot.get("world_feedback", null) is Dictionary:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "world_feedback",
			"expected": "Dictionary",
			"actual_type": typeof(snapshot.get("world_feedback", null)),
		})

	if snapshot.has("creation_params") and not snapshot.get("creation_params", null) is Dictionary:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "creation_params",
			"expected": "Dictionary",
			"actual_type": typeof(snapshot.get("creation_params", null)),
		})

	if snapshot.has("world_seed") and not snapshot.get("world_seed", null) is Dictionary:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "world_seed",
			"expected": "Dictionary",
			"actual_type": typeof(snapshot.get("world_seed", null)),
		})

	if snapshot.has("relationship_network") and not snapshot.get("relationship_network", null) is Dictionary:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "relationship_network",
			"expected": "Dictionary",
			"actual_type": typeof(snapshot.get("relationship_network", null)),
		})

	if snapshot.has("memory_system") and not snapshot.get("memory_system", null) is Dictionary:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "memory_system",
			"expected": "Dictionary",
			"actual_type": typeof(snapshot.get("memory_system", null)),
		})

	if snapshot.has("npc_decision_intervals") and not snapshot.get("npc_decision_intervals", null) is Dictionary:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "npc_decision_intervals",
			"expected": "Dictionary",
			"actual_type": typeof(snapshot.get("npc_decision_intervals", null)),
		})

	if snapshot.has("speed_tier") and not _is_integer_snapshot_number(snapshot.get("speed_tier", null)):
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "speed_tier",
			"expected": "integer number",
			"actual_type": typeof(snapshot.get("speed_tier", null)),
		})

	if not snapshot.get("log_cursor", null) is Dictionary:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "log_cursor",
			"expected": "Dictionary",
			"actual_type": typeof(snapshot.get("log_cursor", null)),
		})
	var log_cursor: Dictionary = snapshot.get("log_cursor", {})
	if not _is_integer_snapshot_number(log_cursor.get("entry_count", null)):
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "log_cursor.entry_count",
			"expected": "integer number",
			"actual_type": typeof(log_cursor.get("entry_count", null)),
		})
	if not log_cursor.get("last_entry_id", "") is String:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "log_cursor.last_entry_id",
			"expected": "String",
			"actual_type": typeof(log_cursor.get("last_entry_id", null)),
		})

	if not snapshot.get("event_log_entries", null) is Array:
		return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
			"field": "event_log_entries",
			"expected": "Array",
			"actual_type": typeof(snapshot.get("event_log_entries", null)),
		})
	var event_entries: Array = snapshot.get("event_log_entries", [])
	for entry in event_entries:
		if not entry is Dictionary:
			return _snapshot_result(false, SNAPSHOT_ERROR_INVALID_FIELD_TYPE, {
				"field": "event_log_entries[]",
				"expected": "Dictionary",
				"actual_type": typeof(entry),
			})

	var expected_entry_count := int(log_cursor.get("entry_count", 0))
	if expected_entry_count != event_entries.size():
		return _snapshot_result(false, SNAPSHOT_ERROR_LOG_CURSOR_MISMATCH, {
			"expected_entry_count": expected_entry_count,
			"actual_entry_count": event_entries.size(),
		})
	var expected_last_entry_id := str(log_cursor.get("last_entry_id", ""))
	if expected_last_entry_id != "":
		var actual_last_entry_id := ""
		if not event_entries.is_empty():
			actual_last_entry_id = str(event_entries[event_entries.size() - 1].get("entry_id", ""))
		if expected_last_entry_id != actual_last_entry_id:
			return _snapshot_result(false, SNAPSHOT_ERROR_LOG_CURSOR_MISMATCH, {
				"expected_last_entry_id": expected_last_entry_id,
				"actual_last_entry_id": actual_last_entry_id,
			})

	var normalized := {
		"snapshot_version": int(snapshot.get("snapshot_version", SNAPSHOT_VERSION)),
		"seed": int(snapshot.get("seed", _seed)),
		"mode": str(snapshot.get("mode", "human")),
		"time": {
			"day": int(time_data.get("day", 1)),
			"minute_of_day": int(time_data.get("minute_of_day", 0)),
		},
		"runtime_characters": _normalize_snapshot_value(runtime_characters_data),
		"world_feedback": _normalize_snapshot_value(snapshot.get("world_feedback", {})),
		"creation_params": _normalize_snapshot_value(snapshot.get("creation_params", {})),
		"world_seed": _normalize_snapshot_value(snapshot.get("world_seed", {})),
		"relationship_network": _normalize_snapshot_value(snapshot.get("relationship_network", {})),
		"memory_system": _normalize_snapshot_value(snapshot.get("memory_system", {})),
		"npc_decision_intervals": _normalize_snapshot_value(snapshot.get("npc_decision_intervals", {})),
		"speed_tier": int(snapshot.get("speed_tier", 2)),
		"log_cursor": {
			"entry_count": expected_entry_count,
			"last_entry_id": str(log_cursor.get("last_entry_id", "")),
		},
		"event_log_entries": _normalize_snapshot_value(event_entries),
	}
	return _snapshot_result(true, SNAPSHOT_ERROR_OK, {}, {
		"snapshot": normalized,
	})


func _is_integer_snapshot_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(value, floor(value))
	return false


func _normalize_snapshot_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result_dict: Dictionary = {}
		for key in value.keys():
			result_dict[str(key)] = _normalize_snapshot_value(value[key])
		return result_dict
	if value is PackedStringArray:
		var string_array: Array = []
		for item in value:
			string_array.append(str(item))
		return string_array
	if value is PackedInt32Array:
		var int_array: Array = []
		for item in value:
			int_array.append(int(item))
		return int_array
	if value is PackedInt64Array:
		var int64_array: Array = []
		for item in value:
			int64_array.append(int(item))
		return int64_array
	if value is PackedFloat32Array:
		var float32_array: Array = []
		for item in value:
			float32_array.append(float(item))
		return float32_array
	if value is PackedFloat64Array:
		var float64_array: Array = []
		for item in value:
			float64_array.append(float(item))
		return float64_array
	if value is PackedByteArray:
		var byte_array: Array = []
		for item in value:
			byte_array.append(int(item))
		return byte_array
	if value is Array:
		var result_array: Array = []
		for item in value:
			result_array.append(_normalize_snapshot_value(item))
		return result_array
	if value is StringName:
		return str(value)
	return value


func _snapshot_result(ok: bool, error_code: String, context: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": ok,
		"error": error_code,
		"context": context.duplicate(true),
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


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


func _location_service() -> Node:
	if _location_service_node != null:
		return _location_service_node
	if not is_inside_tree():
		return null
	var tree := get_tree()
	return tree.root.get_node_or_null("LocationService") if tree != null and tree.root != null else null

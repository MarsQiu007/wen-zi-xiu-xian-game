extends Node
class_name SimulationRunner

const DEFAULT_SEED := 42
const CATALOG_PATH := "res://resources/world/world_data_catalog.tres"
const SeededRandomScript = preload("res://scripts/sim/seeded_random.gd")
const HumanModeRuntimeScript = preload("res://scripts/modes/human/human_mode_runtime.gd")

const NEED_RESOURCE := &"resource_pressure"
const NEED_STABILITY := &"stability"
const NEED_REPUTATION := &"reputation"
const NEED_BELONGING := &"belonging"

signal bootstrapped
signal day_resolved(report: Dictionary)
signal pause_requested(checkpoint: Dictionary)

var _catalog: Resource
var _catalog_path: String = CATALOG_PATH
var _random: RefCounted = SeededRandomScript.new()
var _seed: int = DEFAULT_SEED
var _runtime_characters: Array[Dictionary] = []
var _pending_checkpoint: Dictionary = {}
var _resolved_days: int = 0
var _pause_count: int = 0
var _event_log_node: Node
var _time_service_node: Node
var _run_state_node: Node
var _task7_enabled: bool = false
var _human_mode_runtime: RefCounted = HumanModeRuntimeScript.new()
var _human_mode_options: Dictionary = {}
var _human_runtime: Dictionary = {}


func setup_services(time_service: Node, event_log: Node, run_state: Node) -> void:
	_time_service_node = time_service
	_event_log_node = event_log
	_run_state_node = run_state


func bootstrap(seed: int = DEFAULT_SEED) -> void:
	_catalog = load(_catalog_path)
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
	_task7_enabled = _has_task7_fixture_characters()
	_human_runtime = _build_human_runtime()
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
			"catalog_path": _catalog_path,
			"task7_enabled": _task7_enabled,
			"human_opening_type": str(_human_runtime.get("opening_type", "")),
		},
	})


func configure_seed(seed: int) -> void:
	_seed = seed
	_random.set_seed(seed)


func configure_catalog_path(catalog_path: String) -> void:
	_catalog_path = CATALOG_PATH if catalog_path.is_empty() else catalog_path
	_catalog = null


func configure_human_mode(options: Dictionary) -> void:
	_human_mode_options = options.duplicate(true)


func get_catalog_path() -> String:
	return _catalog_path


func get_seed() -> int:
	return _seed


func get_runtime_characters() -> Array[Dictionary]:
	return _runtime_characters.duplicate(true)


func get_human_runtime() -> Dictionary:
	return _human_runtime.duplicate(true)


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
	_resolve_human_mode_day(simulated_day)
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
	if _task7_enabled:
		_resolve_character_actions(simulated_day)
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
			"focus_tier": str(actor.get("focus_state", {}).get("tier", "")),
			"region_id": str(_resource_get(region, "id", "")) if region != null else "",
			"faction_id": str(_resource_get(faction, "id", "")) if faction != null else "",
			"roll": roll,
			"day": simulated_day,
		},
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

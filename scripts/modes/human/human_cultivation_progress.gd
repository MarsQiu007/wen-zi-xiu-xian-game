extends RefCounted
class_name HumanCultivationProgress

const MORTAL_REALM := "mortal"
const QI_TRAINING_REALM := "qi_training"
const MORTAL_PROGRESS_TARGET := 3
const QI_BREAKTHROUGH_TARGET := 3
const QI_BREAKTHROUGH_CONTACT_REQUIREMENT := 6
const UNLOCKED_GUIDANCE_PROGRESS_BONUS := 2
const EARLY_QI_LIFESPAN_BONUS := 20
const BREAKTHROUGH_FAILURE_LIFESPAN_LOSS := 3
const BREAKTHROUGH_FAILURE_WEAKNESS_DAYS := 2
const PASSIVE_PROGRESS_BONUS_PER_TECHNIQUE := 1
const BREAKTHROUGH_TECHNIQUE_BONUS_RATE := 0.10
const BREAKTHROUGH_ROLL_SCALE := 10000

const SeededRandomScript = preload("res://scripts/sim/seeded_random.gd")


static func sync_active_player_runtime(runtime: Dictionary) -> void:
	var player: Dictionary = (runtime.get("player", {}) as Dictionary).duplicate(true)
	if player.is_empty():
		return
	var gate: Dictionary = _normalize_gate(player.get("cultivation_gate", {}))
	var state: Dictionary = _normalize_state(player, player.get("cultivation_state", {}))
	player["cultivation_gate"] = gate
	player["cultivation_state"] = state
	runtime["player"] = player
	runtime["cultivation_gate"] = gate.duplicate(true)
	runtime["cultivation_state"] = state.duplicate(true)
	var player_id := str(player.get("id", ""))
	if player_id.is_empty():
		return
	var registry: Dictionary = (runtime.get("character_registry", {}) as Dictionary).duplicate(true)
	registry[player_id] = player.duplicate(true)
	runtime["character_registry"] = registry


static func advance_day(runtime: Dictionary, _simulated_day: int) -> Dictionary:
	sync_active_player_runtime(runtime)
	var player: Dictionary = (runtime.get("player", {}) as Dictionary).duplicate(true)
	if player.is_empty():
		return {
			"runtime": runtime,
			"event_type": "",
			"blocked": true,
			"state": {},
			"gate": {},
		}
	var gate: Dictionary = _normalize_gate(player.get("cultivation_gate", {}))
	var state: Dictionary = _normalize_state(player, player.get("cultivation_state", {}))
	if not bool(gate.get("opportunity_unlocked", false)):
		state["last_event"] = "blocked_before_unlock"
		_store_player_state(runtime, player, gate, state)
		return {
			"runtime": runtime,
			"event_type": "",
			"blocked": true,
			"state": state.duplicate(true),
			"gate": gate.duplicate(true),
		}

	state["practice_days"] = int(state.get("practice_days", 0)) + 1
	var weakness_days := int(state.get("weakness_days", 0))
	var progress_gain := 1
	var passive_bonus := _calculate_passive_progress_bonus(player, runtime.get("catalog", null))
	if weakness_days > 0:
		state["weakness_days"] = weakness_days - 1
		progress_gain = 0
	elif _should_apply_unlock_guidance_bonus(state, gate):
		progress_gain += UNLOCKED_GUIDANCE_PROGRESS_BONUS
	if progress_gain > 0:
		progress_gain += passive_bonus

	var event_type := "practice_progress"
	var consequence := ""
	var technique_trace := _build_technique_trace(player, runtime.get("catalog", null))
	technique_trace["passive_progress_bonus"] = passive_bonus
	technique_trace["applied_progress_gain"] = progress_gain
	if str(state.get("realm", MORTAL_REALM)) == MORTAL_REALM:
		state["progress_to_next"] = MORTAL_PROGRESS_TARGET
		state["progress"] = mini(int(state.get("progress", 0)) + progress_gain, MORTAL_PROGRESS_TARGET)
		if int(state.get("progress", 0)) >= MORTAL_PROGRESS_TARGET:
			_enter_qi_training(state)
			event_type = "enter_qi_training"
		elif progress_gain == 0:
			event_type = "recovery"
	else:
		state["progress_to_next"] = QI_BREAKTHROUGH_TARGET
		state["progress"] = mini(int(state.get("progress", 0)) + progress_gain, QI_BREAKTHROUGH_TARGET)
		if progress_gain == 0:
			event_type = "recovery"
		elif int(state.get("progress", 0)) >= QI_BREAKTHROUGH_TARGET:
			var breakthrough := _resolve_breakthrough(state, gate, runtime, player)
			state = breakthrough.get("state", state)
			event_type = str(breakthrough.get("event_type", "qi_training_progress"))
			consequence = str(breakthrough.get("consequence", ""))
			technique_trace["breakthrough_bonus_rate"] = float(breakthrough.get("bonus_rate", 0.0))
			technique_trace["breakthrough_auto_meditated"] = bool(breakthrough.get("auto_meditated", false))
			technique_trace["breakthrough_roll"] = int(breakthrough.get("roll", -1))
			technique_trace["breakthrough_threshold"] = int(breakthrough.get("threshold", -1))
		else:
			event_type = "qi_training_progress"

	state["last_event"] = event_type
	consequence = _decorate_consequence_with_technique(consequence, technique_trace)
	_store_player_state(runtime, player, gate, state)
	return {
		"runtime": runtime,
		"event_type": event_type,
		"blocked": false,
		"state": state.duplicate(true),
		"gate": gate.duplicate(true),
		"consequence": consequence,
		"technique_trace": technique_trace,
	}


static func _should_apply_unlock_guidance_bonus(state: Dictionary, gate: Dictionary) -> bool:
	return str(state.get("realm", MORTAL_REALM)) == MORTAL_REALM \
		and int(state.get("practice_days", 0)) == 1 \
		and bool(gate.get("opportunity_unlocked", false))


static func _resolve_breakthrough(state: Dictionary, gate: Dictionary, runtime: Dictionary, player: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	next_state["breakthrough_attempts"] = int(next_state.get("breakthrough_attempts", 0)) + 1
	var has_technique_bonus := _has_any_learned_technique(player)
	var bonus_rate := BREAKTHROUGH_TECHNIQUE_BONUS_RATE if has_technique_bonus else 0.0
	var roll := -1
	var threshold := -1
	var should_succeed := int(gate.get("contact_score", 0)) >= QI_BREAKTHROUGH_CONTACT_REQUIREMENT
	if not should_succeed and bonus_rate > 0.0:
		var final_success_rate := clampf(bonus_rate, 0.0, 0.95)
		var seeded_rng: SeededRandom = SeededRandomScript.new()
		seeded_rng.set_seed(_build_runtime_seed(runtime, next_state))
		roll = seeded_rng.next_int(BREAKTHROUGH_ROLL_SCALE)
		threshold = int(round(final_success_rate * BREAKTHROUGH_ROLL_SCALE))
		should_succeed = roll < threshold
	if should_succeed:
		next_state["stage_index"] = 2
		next_state["realm"] = QI_TRAINING_REALM
		next_state["realm_label"] = "炼气二层"
		next_state["progress"] = 0
		next_state["progress_to_next"] = QI_BREAKTHROUGH_TARGET
		next_state["last_breakthrough_outcome"] = "success"
		next_state["last_failure_reason"] = ""
		var auto_meditated := _auto_meditate_after_breakthrough(runtime, player)
		return {
			"state": next_state,
			"event_type": "breakthrough_success",
			"consequence": "",
			"bonus_rate": bonus_rate,
			"auto_meditated": auto_meditated,
			"roll": roll,
			"threshold": threshold,
		}
	next_state["progress"] = 0
	next_state["setback_count"] = int(next_state.get("setback_count", 0)) + 1
	next_state["weakness_days"] = BREAKTHROUGH_FAILURE_WEAKNESS_DAYS
	next_state["lifespan_remaining_years"] = maxi(0, int(next_state.get("lifespan_remaining_years", 0)) - BREAKTHROUGH_FAILURE_LIFESPAN_LOSS)
	next_state["last_breakthrough_outcome"] = "failed"
	next_state["last_failure_reason"] = "根基未稳，强行冲关后气血亏虚"
	return {
		"state": next_state,
		"event_type": "breakthrough_failed",
		"consequence": "weakness_and_lifespan_loss",
		"bonus_rate": bonus_rate,
		"auto_meditated": false,
		"roll": roll,
		"threshold": threshold,
	}


static func _calculate_passive_progress_bonus(player: Dictionary, catalog: Resource) -> int:
	var passive_count := _count_equipped_passive_techniques(player, catalog)
	if passive_count <= 0:
		return 0
	return passive_count * PASSIVE_PROGRESS_BONUS_PER_TECHNIQUE


static func _count_equipped_passive_techniques(player: Dictionary, catalog: Resource) -> int:
	if catalog == null or not catalog.has_method("find_technique"):
		return 0
	var learned_raw: Variant = player.get("learned_techniques", [])
	if not (learned_raw is Array):
		return 0
	var count := 0
	for entry in learned_raw:
		if not (entry is Dictionary):
			continue
		var learned: Dictionary = entry
		var equipped_slot := str(learned.get("equipped_slot", "")).strip_edges()
		if equipped_slot.is_empty():
			continue
		var technique_id := str(learned.get("technique_id", "")).strip_edges()
		if technique_id.is_empty():
			continue
		var technique: Resource = catalog.find_technique(StringName(technique_id))
		if technique == null:
			continue
		if str(_resource_get(technique, "technique_type", "")) == "passive_method":
			count += 1
	return count


static func _build_technique_trace(player: Dictionary, catalog: Resource) -> Dictionary:
	var equipped_ids: Array[String] = []
	var passive_ids: Array[String] = []
	var learned_raw: Variant = player.get("learned_techniques", [])
	if learned_raw is Array:
		for entry in learned_raw:
			if not (entry is Dictionary):
				continue
			var learned: Dictionary = entry
			var equipped_slot := str(learned.get("equipped_slot", "")).strip_edges()
			if equipped_slot.is_empty():
				continue
			var technique_id := str(learned.get("technique_id", "")).strip_edges()
			if technique_id.is_empty():
				continue
			equipped_ids.append(technique_id)
			if catalog != null and catalog.has_method("find_technique"):
				var technique: Resource = catalog.find_technique(StringName(technique_id))
				if technique != null and str(_resource_get(technique, "technique_type", "")) == "passive_method":
					passive_ids.append(technique_id)
	return {
		"equipped_technique_ids": equipped_ids,
		"passive_technique_ids": passive_ids,
		"has_any_technique": not equipped_ids.is_empty(),
	}


static func _has_any_learned_technique(player: Dictionary) -> bool:
	var learned_raw: Variant = player.get("learned_techniques", [])
	if not (learned_raw is Array):
		return false
	for entry in learned_raw:
		if not (entry is Dictionary):
			continue
		var technique_id := str((entry as Dictionary).get("technique_id", "")).strip_edges()
		if not technique_id.is_empty():
			return true
	return false


static func _build_runtime_seed(runtime: Dictionary, state: Dictionary) -> int:
	var day_seed := int(runtime.get("day_count", 0))
	var attempt_seed := int(state.get("breakthrough_attempts", 0))
	var contact_seed := int((runtime.get("cultivation_gate", {}) as Dictionary).get("contact_score", 0))
	var mixed := 104729 + day_seed * 131 + attempt_seed * 977 + contact_seed * 7919
	return maxi(1, mixed)


static func _auto_meditate_after_breakthrough(runtime: Dictionary, player: Dictionary) -> bool:
	var technique_service := _resolve_technique_service(runtime)
	if technique_service == null:
		return false
	if not (runtime.get("catalog", null) is WorldDataCatalog):
		return false
	var player_id := str(player.get("id", "")).strip_edges()
	if player_id.is_empty():
		return false
	var learned_techniques: Array[Dictionary] = technique_service.get_learned_techniques(player_id)
	if learned_techniques.is_empty():
		return false
	var target_technique_id := ""
	for learned in learned_techniques:
		var technique_id := str(learned.get("technique_id", "")).strip_edges()
		if technique_id.is_empty():
			continue
		target_technique_id = technique_id
		break
	if target_technique_id.is_empty():
		return false
	var seeded_rng: SeededRandom = SeededRandomScript.new()
	var runtime_state: Dictionary = runtime.get("cultivation_state", {}) as Dictionary
	seeded_rng.set_seed(_build_runtime_seed(runtime, runtime_state) + 17)
	var outcome: Dictionary = technique_service.meditate_affix(player_id, target_technique_id, 0, seeded_rng)
	var success := bool(outcome.get("success", false))
	if success:
		_sync_player_techniques_from_service(runtime, player, technique_service)
	return success


static func _resolve_technique_service(runtime: Dictionary) -> TechniqueService:
	var existing: Variant = runtime.get("technique_service", null)
	if existing is TechniqueService:
		return existing as TechniqueService
	var created: TechniqueService = TechniqueService.new()
	var catalog: Variant = runtime.get("catalog", null)
	if catalog is WorldDataCatalog:
		created.bind_catalog(catalog as WorldDataCatalog)
	runtime["technique_service"] = created
	return created


static func _sync_player_techniques_from_service(runtime: Dictionary, player: Dictionary, technique_service: TechniqueService) -> void:
	var player_id := str(player.get("id", "")).strip_edges()
	if player_id.is_empty():
		return
	var learned_techniques: Array[Dictionary] = technique_service.get_learned_techniques(player_id)
	if learned_techniques.is_empty():
		return
	var next_player: Dictionary = player.duplicate(true)
	next_player["learned_techniques"] = learned_techniques.duplicate(true)
	runtime["player"] = next_player
	var registry: Dictionary = (runtime.get("character_registry", {}) as Dictionary).duplicate(true)
	if registry.has(player_id):
		var registry_player: Dictionary = (registry.get(player_id, {}) as Dictionary).duplicate(true)
		registry_player["learned_techniques"] = learned_techniques.duplicate(true)
		registry[player_id] = registry_player
		runtime["character_registry"] = registry


static func _decorate_consequence_with_technique(consequence: String, technique_trace: Dictionary) -> String:
	var passive_ids: Array = technique_trace.get("passive_technique_ids", [])
	var equipped_ids: Array = technique_trace.get("equipped_technique_ids", [])
	var passive_count := passive_ids.size() if passive_ids is Array else 0
	var equipped_count := equipped_ids.size() if equipped_ids is Array else 0
	var appendix := "technique_info:equip=%d,passive=%d,bonus=%d" % [
		equipped_count,
		passive_count,
		int(technique_trace.get("passive_progress_bonus", 0)),
	]
	if consequence.strip_edges().is_empty():
		return appendix
	return "%s|%s" % [consequence, appendix]


static func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value


static func _enter_qi_training(state: Dictionary) -> void:
	state["realm"] = QI_TRAINING_REALM
	state["realm_label"] = "炼气一层"
	state["stage_index"] = 1
	state["progress"] = 0
	state["progress_to_next"] = QI_BREAKTHROUGH_TARGET
	state["lifespan_limit_years"] = int(state.get("lifespan_limit_years", 60)) + EARLY_QI_LIFESPAN_BONUS
	state["lifespan_remaining_years"] = int(state.get("lifespan_remaining_years", 0)) + EARLY_QI_LIFESPAN_BONUS
	state["last_breakthrough_outcome"] = "entered_qi_training"
	state["last_failure_reason"] = ""


static func _store_player_state(runtime: Dictionary, player: Dictionary, gate: Dictionary, state: Dictionary) -> void:
	var next_player: Dictionary = player.duplicate(true)
	next_player["cultivation_gate"] = gate.duplicate(true)
	next_player["cultivation_state"] = state.duplicate(true)
	runtime["player"] = next_player
	runtime["cultivation_gate"] = gate.duplicate(true)
	runtime["cultivation_state"] = state.duplicate(true)
	var player_id := str(next_player.get("id", ""))
	if player_id.is_empty():
		return
	var registry: Dictionary = (runtime.get("character_registry", {}) as Dictionary).duplicate(true)
	registry[player_id] = next_player.duplicate(true)
	runtime["character_registry"] = registry


static func _normalize_gate(raw_gate: Variant) -> Dictionary:
	var source: Dictionary = raw_gate.duplicate(true) if raw_gate is Dictionary else {}
	return {
		"contact_score": int(source.get("contact_score", 0)),
		"has_active_contact": bool(source.get("has_active_contact", false)),
		"opportunity_unlocked": bool(source.get("opportunity_unlocked", false)),
		"last_contact_action": str(source.get("last_contact_action", "")),
		"faith_contact_score": int(source.get("faith_contact_score", 0)),
		"orthodox_suspicion": int(source.get("orthodox_suspicion", 0)),
		"last_faith_action": str(source.get("last_faith_action", "")),
		"faith_marked": bool(source.get("faith_marked", false)),
	}


static func _normalize_state(player: Dictionary, raw_state: Variant) -> Dictionary:
	var source: Dictionary = raw_state.duplicate(true) if raw_state is Dictionary else {}
	var age_years := int(player.get("age_years", 14))
	var lifespan_limit := int(source.get("lifespan_limit_years", maxi(60, age_years + 40)))
	var lifespan_remaining := int(source.get("lifespan_remaining_years", maxi(0, lifespan_limit - age_years)))
	return {
		"realm": str(source.get("realm", MORTAL_REALM)),
		"realm_label": str(source.get("realm_label", "凡体")),
		"stage_index": int(source.get("stage_index", 0)),
		"progress": int(source.get("progress", 0)),
		"progress_to_next": int(source.get("progress_to_next", MORTAL_PROGRESS_TARGET)),
		"practice_days": int(source.get("practice_days", 0)),
		"breakthrough_attempts": int(source.get("breakthrough_attempts", 0)),
		"setback_count": int(source.get("setback_count", 0)),
		"weakness_days": int(source.get("weakness_days", 0)),
		"lifespan_limit_years": lifespan_limit,
		"lifespan_remaining_years": lifespan_remaining,
		"last_breakthrough_outcome": str(source.get("last_breakthrough_outcome", "")),
		"last_failure_reason": str(source.get("last_failure_reason", "")),
		"last_event": str(source.get("last_event", "")),
	}

extends RefCounted
class_name HumanCultivationProgress

const MORTAL_REALM := "mortal"
const QI_TRAINING_REALM := "qi_training"
const MORTAL_PROGRESS_TARGET := 2
const QI_BREAKTHROUGH_TARGET := 2
const QI_BREAKTHROUGH_CONTACT_REQUIREMENT := 6
const EARLY_QI_LIFESPAN_BONUS := 20
const BREAKTHROUGH_FAILURE_LIFESPAN_LOSS := 3
const BREAKTHROUGH_FAILURE_WEAKNESS_DAYS := 2


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
	if weakness_days > 0:
		state["weakness_days"] = weakness_days - 1
		progress_gain = 0

	var event_type := "practice_progress"
	var consequence := ""
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
			var breakthrough := _resolve_breakthrough(state, gate)
			state = breakthrough.get("state", state)
			event_type = str(breakthrough.get("event_type", "qi_training_progress"))
			consequence = str(breakthrough.get("consequence", ""))
		else:
			event_type = "qi_training_progress"

	state["last_event"] = event_type
	_store_player_state(runtime, player, gate, state)
	return {
		"runtime": runtime,
		"event_type": event_type,
		"blocked": false,
		"state": state.duplicate(true),
		"gate": gate.duplicate(true),
		"consequence": consequence,
	}


static func _resolve_breakthrough(state: Dictionary, gate: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	next_state["breakthrough_attempts"] = int(next_state.get("breakthrough_attempts", 0)) + 1
	if int(gate.get("contact_score", 0)) >= QI_BREAKTHROUGH_CONTACT_REQUIREMENT:
		next_state["stage_index"] = 2
		next_state["realm"] = QI_TRAINING_REALM
		next_state["realm_label"] = "炼气二层"
		next_state["progress"] = 0
		next_state["progress_to_next"] = QI_BREAKTHROUGH_TARGET
		next_state["last_breakthrough_outcome"] = "success"
		next_state["last_failure_reason"] = ""
		return {
			"state": next_state,
			"event_type": "breakthrough_success",
			"consequence": "",
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
	}


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

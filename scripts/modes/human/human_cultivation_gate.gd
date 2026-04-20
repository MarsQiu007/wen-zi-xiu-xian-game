extends RefCounted
class_name HumanCultivationGate

const OPPORTUNITY_CONTACT_THRESHOLD := 4


static func apply_action(runtime: Dictionary, action_id: String, action_def: Dictionary) -> Dictionary:
	var next_runtime: Dictionary = runtime.duplicate(true)
	var player: Dictionary = (next_runtime.get("player", {}) as Dictionary).duplicate(true)
	var gate_source: Variant = player.get("cultivation_gate", next_runtime.get("cultivation_gate", {}))
	var gate: Dictionary = gate_source.duplicate(true) if gate_source is Dictionary else {}
	var is_active_contact := bool(action_def.get("active_contact", false))
	var contact_gain := int(action_def.get("contact_gain", 0)) if is_active_contact else 0
	var is_faith_contact := bool(action_def.get("faith_contact", false))
	var faith_contact_gain := int(action_def.get("faith_contact_gain", 0)) if is_faith_contact else 0
	var orthodox_suspicion_gain := int(action_def.get("orthodox_suspicion_gain", 0)) if is_faith_contact else 0
	var unlocked_before := bool(gate.get("opportunity_unlocked", false))
	if is_active_contact:
		gate["has_active_contact"] = true
		gate["contact_score"] = int(gate.get("contact_score", 0)) + contact_gain
		gate["last_contact_action"] = action_id
	if is_faith_contact:
		gate["faith_contact_score"] = int(gate.get("faith_contact_score", 0)) + faith_contact_gain
		gate["orthodox_suspicion"] = int(gate.get("orthodox_suspicion", 0)) + orthodox_suspicion_gain
		gate["last_faith_action"] = action_id
		gate["faith_marked"] = int(gate.get("faith_contact_score", 0)) >= 2
	gate["opportunity_unlocked"] = bool(gate.get("has_active_contact", false)) and int(gate.get("contact_score", 0)) >= OPPORTUNITY_CONTACT_THRESHOLD
	if not player.is_empty():
		player["cultivation_gate"] = gate.duplicate(true)
		next_runtime["player"] = player
		var player_id := str(player.get("id", ""))
		if not player_id.is_empty():
			var registry: Dictionary = (next_runtime.get("character_registry", {}) as Dictionary).duplicate(true)
			registry[player_id] = player.duplicate(true)
			next_runtime["character_registry"] = registry
	next_runtime["cultivation_gate"] = gate
	return {
		"runtime": next_runtime,
		"contact_gain": contact_gain,
		"faith_contact_gain": faith_contact_gain,
		"orthodox_suspicion_gain": orthodox_suspicion_gain,
		"unlocked_now": bool(gate.get("opportunity_unlocked", false)) and not unlocked_before,
	}

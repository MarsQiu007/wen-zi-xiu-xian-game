extends RefCounted
class_name HumanCultivationGate

const OPPORTUNITY_CONTACT_THRESHOLD := 4


static func apply_action(runtime: Dictionary, action_id: String, action_def: Dictionary) -> Dictionary:
	var next_runtime: Dictionary = runtime.duplicate(true)
	var gate: Dictionary = next_runtime.get("cultivation_gate", {}).duplicate(true)
	var is_active_contact := bool(action_def.get("active_contact", false))
	var contact_gain := int(action_def.get("contact_gain", 0)) if is_active_contact else 0
	var unlocked_before := bool(gate.get("opportunity_unlocked", false))
	if is_active_contact:
		gate["has_active_contact"] = true
		gate["contact_score"] = int(gate.get("contact_score", 0)) + contact_gain
		gate["last_contact_action"] = action_id
	gate["opportunity_unlocked"] = bool(gate.get("has_active_contact", false)) and int(gate.get("contact_score", 0)) >= OPPORTUNITY_CONTACT_THRESHOLD
	next_runtime["cultivation_gate"] = gate
	return {
		"runtime": next_runtime,
		"contact_gain": contact_gain,
		"unlocked_now": bool(gate.get("opportunity_unlocked", false)) and not unlocked_before,
	}

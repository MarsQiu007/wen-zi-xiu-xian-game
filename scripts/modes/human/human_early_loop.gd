extends RefCounted
class_name HumanEarlyLoop

const HumanCultivationGateScript = preload("res://scripts/modes/human/human_cultivation_gate.gd")
const HumanCultivationProgressScript = preload("res://scripts/modes/human/human_cultivation_progress.gd")

const BRANCHES := ["survival", "family", "learning", "cultivation"]

const ACTION_DEFS := {
	"work_for_food": {
		"label": "外出讨生活",
		"branch": "survival",
		"pressure_deltas": {
			"survival": -3,
			"family": 0,
			"learning": 1,
			"cultivation": 1,
		},
		"active_contact": false,
		"contact_gain": 0,
	},
	"support_family": {
		"label": "分担家中事务",
		"branch": "family",
		"pressure_deltas": {
			"survival": -1,
			"family": -3,
			"learning": 0,
			"cultivation": 1,
		},
		"active_contact": false,
		"contact_gain": 0,
	},
	"study_classics": {
		"label": "研读乡塾典籍",
		"branch": "learning",
		"pressure_deltas": {
			"survival": 0,
			"family": 0,
			"learning": -3,
			"cultivation": 1,
		},
		"active_contact": false,
		"contact_gain": 0,
	},
	"seek_master": {
		"label": "打听仙门引路人",
		"branch": "cultivation",
		"pressure_deltas": {
			"survival": 1,
			"family": 1,
			"learning": 0,
			"cultivation": -2,
		},
		"active_contact": true,
		"contact_gain": 2,
	},
	"visit_sect": {
		"label": "前往山门外探访",
		"branch": "cultivation",
		"pressure_deltas": {
			"survival": 1,
			"family": 1,
			"learning": 0,
			"cultivation": -1,
		},
		"active_contact": true,
		"contact_gain": 2,
	},
	"ask_for_guidance": {
		"label": "向散修请教门路",
		"branch": "cultivation",
		"pressure_deltas": {
			"survival": 0,
			"family": 1,
			"learning": -1,
			"cultivation": -2,
		},
		"active_contact": true,
		"contact_gain": 2,
	},
	"visit_shrine": {
		"label": "暗访偏祠问神",
		"branch": "cultivation",
		"pressure_deltas": {
			"survival": 1,
			"family": 2,
			"learning": 0,
			"cultivation": -1,
		},
		"active_contact": false,
		"contact_gain": 0,
		"faith_contact": true,
		"faith_contact_gain": 2,
		"orthodox_suspicion_gain": 2,
	},
	"seek_oracle": {
		"label": "追索神迹传闻",
		"branch": "cultivation",
		"pressure_deltas": {
			"survival": 1,
			"family": 1,
			"learning": 0,
			"cultivation": -1,
		},
		"active_contact": false,
		"contact_gain": 0,
		"faith_contact": true,
		"faith_contact_gain": 2,
		"orthodox_suspicion_gain": 1,
	},
}

const DEFAULT_ACTION_BY_BRANCH := {
	"survival": "work_for_food",
	"family": "support_family",
	"learning": "study_classics",
	"cultivation": "seek_master",
}

const ACTIVE_CULTIVATION_ROTATION := ["seek_master", "visit_sect", "ask_for_guidance"]
const ACTIVE_FAITH_ROTATION := ["visit_shrine", "seek_oracle", "visit_shrine"]
const YOUTH_DEFAULT_CULTIVATION_PLAN := ["seek_master", "visit_sect", "ask_for_guidance"]


static func advance_day(runtime: Dictionary, simulated_day: int) -> Dictionary:
	var next_runtime: Dictionary = runtime.duplicate(true)
	if bool(next_runtime.get("lineage", {}).get("terminated", false)):
		next_runtime["day_count"] = simulated_day
		return {
			"runtime": next_runtime,
			"action": {},
			"unlocked_now": false,
			"perspective_switched": false,
			"death_triggered": false,
			"termination_triggered": true,
			"death_summary": next_runtime.get("lineage", {}).get("last_death", {}),
		}
	var death_resolution := _resolve_forced_death(next_runtime, simulated_day)
	if bool(death_resolution.get("death_triggered", false)):
		return {
			"runtime": death_resolution.get("runtime", next_runtime),
			"action": death_resolution.get("action", {}),
			"unlocked_now": false,
			"perspective_switched": bool(death_resolution.get("perspective_switched", false)),
			"death_triggered": true,
			"termination_triggered": bool(death_resolution.get("termination_triggered", false)),
			"death_summary": death_resolution.get("death_summary", {}),
		}
	_apply_daily_drift(next_runtime)
	var action_id := _pick_action_id(next_runtime, simulated_day)
	var action_def: Dictionary = ACTION_DEFS.get(action_id, ACTION_DEFS["work_for_food"])
	_apply_pressure_deltas(next_runtime, action_def.get("pressure_deltas", {}))
	var gate_resolution := HumanCultivationGateScript.apply_action(next_runtime, action_id, action_def)
	next_runtime = gate_resolution.get("runtime", next_runtime)
	var cultivation_resolution := HumanCultivationProgressScript.advance_day(next_runtime, simulated_day)
	next_runtime = cultivation_resolution.get("runtime", next_runtime)
	var dominant_branch := _select_dominant_branch(next_runtime)
	next_runtime["dominant_branch"] = dominant_branch
	next_runtime["day_count"] = simulated_day
	var cultivation_state: Dictionary = next_runtime.get("cultivation_state", {})
	var action_summary := {
		"day": simulated_day,
		"action_id": action_id,
		"label": str(action_def.get("label", action_id)),
		"branch": str(action_def.get("branch", dominant_branch)),
		"contact_gain": int(gate_resolution.get("contact_gain", 0)),
		"faith_contact_gain": int(gate_resolution.get("faith_contact_gain", 0)),
		"orthodox_suspicion_gain": int(gate_resolution.get("orthodox_suspicion_gain", 0)),
		"dominant_branch": dominant_branch,
		"cultivation_realm": str(cultivation_state.get("realm", "mortal")),
		"cultivation_stage_label": str(cultivation_state.get("realm_label", "凡体")),
	}
	var recent_actions: Array = next_runtime.get("recent_actions", []).duplicate(true)
	recent_actions.append(action_summary)
	if recent_actions.size() > 5:
		recent_actions = recent_actions.slice(recent_actions.size() - 5, recent_actions.size())
	next_runtime["recent_actions"] = recent_actions
	return {
		"runtime": next_runtime,
		"action": action_summary,
		"unlocked_now": bool(gate_resolution.get("unlocked_now", false)),
		"perspective_switched": false,
		"death_triggered": false,
		"termination_triggered": false,
		"death_summary": {},
		"cultivation": cultivation_resolution,
	}


static func _resolve_forced_death(runtime: Dictionary, simulated_day: int) -> Dictionary:
	var forced_death_day := int(runtime.get("forced_death_day", 0))
	if forced_death_day <= 0 or simulated_day != forced_death_day:
		return {
			"runtime": runtime,
			"death_triggered": false,
		}
	var lineage: Dictionary = runtime.get("lineage", {}).duplicate(true)
	var registry: Dictionary = runtime.get("character_registry", {}).duplicate(true)
	var current_player: Dictionary = runtime.get("player", {}).duplicate(true)
	var deceased_id := str(current_player.get("id", ""))
	if deceased_id.is_empty() or not registry.has(deceased_id):
		return {
			"runtime": runtime,
			"death_triggered": false,
		}
	var deceased: Dictionary = (registry[deceased_id] as Dictionary).duplicate(true)
	deceased["is_alive"] = false
	registry[deceased_id] = deceased
	var inheritance := _select_heir(runtime, deceased)
	var heir_id := str(inheritance.get("heir_id", ""))
	var death_summary := {
		"deceased_id": deceased_id,
		"deceased_name": str(deceased.get("display_name", deceased_id)),
		"heir_id": heir_id,
		"heir_name": "",
		"reason": str(inheritance.get("reason", "none")),
		"used_direct_line": bool(inheritance.get("used_direct_line", false)),
		"used_legal_heir": bool(inheritance.get("used_legal_heir", false)),
	}
	lineage["last_death"] = death_summary.duplicate(true)
	if heir_id.is_empty() or not registry.has(heir_id):
		lineage["terminated"] = true
		lineage["termination_reason"] = "no_heir_after_death"
		lineage["active_character_id"] = ""
		runtime["lineage"] = lineage
		runtime["character_registry"] = registry
		runtime["player"] = deceased
		runtime["current_player_id"] = ""
		runtime["cultivation_gate"] = (deceased.get("cultivation_gate", {}) as Dictionary).duplicate(true)
		runtime["cultivation_state"] = (deceased.get("cultivation_state", {}) as Dictionary).duplicate(true)
		runtime["day_count"] = simulated_day
		return {
			"runtime": runtime,
			"action": {
				"day": simulated_day,
				"action_id": "human_lineage_terminated",
				"label": "家系断绝",
				"branch": "family",
				"contact_gain": 0,
				"dominant_branch": str(runtime.get("dominant_branch", "family")),
			},
			"perspective_switched": false,
			"death_triggered": true,
			"termination_triggered": true,
			"death_summary": death_summary,
		}
	var heir: Dictionary = (registry[heir_id] as Dictionary).duplicate(true)
	death_summary["heir_name"] = str(heir.get("display_name", heir_id))
	lineage["last_death"] = death_summary.duplicate(true)
	lineage["terminated"] = false
	lineage["termination_reason"] = ""
	lineage["active_character_id"] = heir_id
	var perspective_history: Array = lineage.get("perspective_history", []).duplicate(true)
	perspective_history.append(heir_id)
	lineage["perspective_history"] = perspective_history
	runtime["lineage"] = lineage
	runtime["character_registry"] = registry
	runtime["player"] = heir
	runtime["current_player_id"] = heir_id
	HumanCultivationProgressScript.sync_active_player_runtime(runtime)
	runtime["day_count"] = simulated_day
	return {
		"runtime": runtime,
		"action": {
			"day": simulated_day,
			"action_id": "human_inheritance_transition",
			"label": "继承转承",
			"branch": "family",
			"contact_gain": 0,
			"dominant_branch": "family",
		},
		"perspective_switched": true,
		"death_triggered": true,
		"termination_triggered": false,
		"death_summary": death_summary,
	}


static func _select_heir(runtime: Dictionary, deceased: Dictionary) -> Dictionary:
	var registry: Dictionary = runtime.get("character_registry", {})
	var direct_line_child_ids: Array[String] = _coerce_string_array(deceased.get("direct_line_child_ids", []))
	var best_direct_line_id := ""
	var best_direct_line_priority := 999999
	for child_id in direct_line_child_ids:
		if not registry.has(child_id):
			continue
		var child: Dictionary = registry.get(child_id, {})
		if not bool(child.get("is_alive", true)):
			continue
		var priority := int(child.get("inheritance_priority", 999999))
		if best_direct_line_id.is_empty() or priority < best_direct_line_priority:
			best_direct_line_id = child_id
			best_direct_line_priority = priority
	if not best_direct_line_id.is_empty():
		return {
			"heir_id": best_direct_line_id,
			"reason": "direct_line_descendant",
			"used_direct_line": true,
			"used_legal_heir": false,
		}
	var legal_heir_id := str(deceased.get("legal_heir_character_id", ""))
	if not legal_heir_id.is_empty() and registry.has(legal_heir_id):
		var legal_heir: Dictionary = registry.get(legal_heir_id, {})
		if bool(legal_heir.get("is_alive", true)):
			return {
				"heir_id": legal_heir_id,
				"reason": "designated_legal_heir",
				"used_direct_line": false,
				"used_legal_heir": true,
			}
	return {
		"heir_id": "",
		"reason": "no_eligible_heir",
		"used_direct_line": false,
		"used_legal_heir": false,
	}


static func _coerce_string_array(raw_value: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_value is PackedStringArray:
		for item in raw_value:
			result.append(str(item))
	elif raw_value is Array:
		for item in raw_value:
			result.append(str(item))
	return result


static func _pick_action_id(runtime: Dictionary, simulated_day: int) -> String:
	var action_plan: Array = runtime.get("action_plan", [])
	var plan_index := simulated_day - 1
	if plan_index >= 0 and plan_index < action_plan.size():
		return str(action_plan[plan_index])
	var opening_type := str(runtime.get("opening_type", ""))
	if opening_type == "youth":
		var gate: Dictionary = runtime.get("cultivation_gate", {})
		var contact_score := int(gate.get("contact_score", 0))
		var opportunity_unlocked := bool(gate.get("opportunity_unlocked", false))
		var cultivation_pressure := int(runtime.get("pressures", {}).get("cultivation", 0))
		if not opportunity_unlocked and contact_score > 0 and cultivation_pressure >= 8:
			return str(YOUTH_DEFAULT_CULTIVATION_PLAN[(contact_score - 1) % YOUTH_DEFAULT_CULTIVATION_PLAN.size()])
	var strategy := str(runtime.get("strategy", ""))
	match strategy:
		"survival", "family", "learning", "cultivation":
			return str(DEFAULT_ACTION_BY_BRANCH.get(strategy, "work_for_food"))
		"active_cultivation":
			return str(ACTIVE_CULTIVATION_ROTATION[plan_index % ACTIVE_CULTIVATION_ROTATION.size()])
		"faith_seek":
			return str(ACTIVE_FAITH_ROTATION[plan_index % ACTIVE_FAITH_ROTATION.size()])
		"passive":
			return str(DEFAULT_ACTION_BY_BRANCH.get(_select_passive_branch(runtime), "work_for_food"))
		_:
			return str(DEFAULT_ACTION_BY_BRANCH.get(_select_dominant_branch(runtime), "work_for_food"))


static func _select_passive_branch(runtime: Dictionary) -> String:
	var pressures: Dictionary = runtime.get("pressures", {})
	var weights: Dictionary = runtime.get("branch_weights", {})
	var best_branch := "survival"
	var best_score := -999999
	for branch in ["survival", "family", "learning"]:
		var score := int(pressures.get(branch, 0)) + int(weights.get(branch, 0))
		if score > best_score:
			best_score = score
			best_branch = branch
	return best_branch


static func _select_dominant_branch(runtime: Dictionary) -> String:
	var pressures: Dictionary = runtime.get("pressures", {})
	var weights: Dictionary = runtime.get("branch_weights", {})
	var cultivation_gate: Dictionary = runtime.get("cultivation_gate", {})
	var has_active_contact := bool(cultivation_gate.get("has_active_contact", false))
	var best_branch := "survival"
	var best_score := -999999
	for branch in BRANCHES:
		var score := int(pressures.get(branch, 0)) + int(weights.get(branch, 0))
		if branch == "cultivation":
			score += int(cultivation_gate.get("contact_score", 0))
			score += 4 if has_active_contact else -6
		if score > best_score:
			best_score = score
			best_branch = branch
	return best_branch


static func _apply_daily_drift(runtime: Dictionary) -> void:
	var opening_type := str(runtime.get("opening_type", "youth"))
	var drift := {
		"survival": 1,
		"family": 1,
		"learning": 1,
		"cultivation": 1,
	}
	match opening_type:
		"youth":
			drift = {
				"survival": 1,
				"family": 0,
				"learning": 2,
				"cultivation": 1,
			}
		"young_adult":
			drift = {
				"survival": 1,
				"family": 2,
				"learning": 0,
				"cultivation": 1,
			}
		"adult":
			drift = {
				"survival": 3,
				"family": 1,
				"learning": 0,
				"cultivation": 1,
			}
	_apply_pressure_deltas(runtime, drift)


static func _apply_pressure_deltas(runtime: Dictionary, deltas: Dictionary) -> void:
	var pressures: Dictionary = runtime.get("pressures", {}).duplicate(true)
	for branch in BRANCHES:
		var next_value := int(pressures.get(branch, 0)) + int(deltas.get(branch, 0))
		pressures[branch] = clampi(next_value, 0, 20)
	runtime["pressures"] = pressures

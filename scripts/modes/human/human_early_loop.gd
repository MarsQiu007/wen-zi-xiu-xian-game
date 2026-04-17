extends RefCounted
class_name HumanEarlyLoop

const HumanCultivationGateScript = preload("res://scripts/modes/human/human_cultivation_gate.gd")

const BRANCHES := ["survival", "family", "learning", "cultivation"]

const ACTION_DEFS := {
	"work_for_food": {
		"label": "外出讨生活",
		"branch": "survival",
		"pressure_deltas": {
			"survival": -2,
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
}

const DEFAULT_ACTION_BY_BRANCH := {
	"survival": "work_for_food",
	"family": "support_family",
	"learning": "study_classics",
	"cultivation": "seek_master",
}

const ACTIVE_CULTIVATION_ROTATION := ["seek_master", "visit_sect", "ask_for_guidance"]


static func advance_day(runtime: Dictionary, simulated_day: int) -> Dictionary:
	var next_runtime: Dictionary = runtime.duplicate(true)
	_apply_daily_drift(next_runtime)
	var action_id := _pick_action_id(next_runtime, simulated_day)
	var action_def: Dictionary = ACTION_DEFS.get(action_id, ACTION_DEFS["work_for_food"])
	_apply_pressure_deltas(next_runtime, action_def.get("pressure_deltas", {}))
	var gate_resolution := HumanCultivationGateScript.apply_action(next_runtime, action_id, action_def)
	next_runtime = gate_resolution.get("runtime", next_runtime)
	var dominant_branch := _select_dominant_branch(next_runtime)
	next_runtime["dominant_branch"] = dominant_branch
	next_runtime["day_count"] = simulated_day
	var action_summary := {
		"day": simulated_day,
		"action_id": action_id,
		"label": str(action_def.get("label", action_id)),
		"branch": str(action_def.get("branch", dominant_branch)),
		"contact_gain": int(gate_resolution.get("contact_gain", 0)),
		"dominant_branch": dominant_branch,
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
	}


static func _pick_action_id(runtime: Dictionary, simulated_day: int) -> String:
	var action_plan: Array = runtime.get("action_plan", [])
	var plan_index := simulated_day - 1
	if plan_index >= 0 and plan_index < action_plan.size():
		return str(action_plan[plan_index])
	var strategy := str(runtime.get("strategy", ""))
	match strategy:
		"survival", "family", "learning", "cultivation":
			return str(DEFAULT_ACTION_BY_BRANCH.get(strategy, "work_for_food"))
		"active_cultivation":
			return str(ACTIVE_CULTIVATION_ROTATION[plan_index % ACTIVE_CULTIVATION_ROTATION.size()])
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

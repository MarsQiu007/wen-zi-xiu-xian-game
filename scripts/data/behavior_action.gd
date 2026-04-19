extends RefCounted
class_name BehaviorAction

const SNAPSHOT_VERSION := 1

var action_id: StringName = &""
var label: String = ""
var category: StringName = &""
var pressure_deltas: Dictionary = {}
var favor_deltas: Dictionary = {}
var conditions: Dictionary = {}
var weight: float = 1.0
var description: String = ""
var cooldown_hours: float = 0.0


func to_dict() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"action_id": String(action_id),
		"label": label,
		"category": String(category),
		"pressure_deltas": pressure_deltas.duplicate(true),
		"favor_deltas": favor_deltas.duplicate(true),
		"conditions": conditions.duplicate(true),
		"weight": weight,
		"description": description,
		"cooldown_hours": cooldown_hours,
	}


static func from_dict(data: Dictionary) -> BehaviorAction:
	var result := BehaviorAction.new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result.action_id = StringName(str(data.get("action_id", "")))
	result.label = str(data.get("label", ""))
	result.category = StringName(str(data.get("category", "")))
	result.pressure_deltas = (data.get("pressure_deltas", {}) as Dictionary).duplicate(true)
	result.favor_deltas = (data.get("favor_deltas", {}) as Dictionary).duplicate(true)
	result.conditions = (data.get("conditions", {}) as Dictionary).duplicate(true)
	result.weight = float(data.get("weight", 1.0))
	result.description = str(data.get("description", ""))
	result.cooldown_hours = float(data.get("cooldown_hours", 0.0))
	return result

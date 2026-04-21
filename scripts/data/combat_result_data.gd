extends RefCounted
class_name CombatResultData

const SNAPSHOT_VERSION := 1

var victor_id: String = ""
var turns_elapsed: int = 0
var loot: Array[Dictionary] = []
var combat_log: Array[String] = []
var participant_states: Array[Dictionary] = []


func to_dict() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"victor_id": victor_id,
		"turns_elapsed": turns_elapsed,
		"loot": loot.duplicate(true),
		"combat_log": combat_log.duplicate(true),
		"participant_states": participant_states.duplicate(true),
	}


static func from_dict(data: Dictionary) -> CombatResultData:
	var result := CombatResultData.new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result.victor_id = str(data.get("victor_id", ""))
	result.turns_elapsed = int(data.get("turns_elapsed", 0))
	result.loot = (data.get("loot", []) as Array).duplicate(true)
	result.combat_log = (data.get("combat_log", []) as Array).duplicate(true)
	result.participant_states = (data.get("participant_states", []) as Array).duplicate(true)
	return result

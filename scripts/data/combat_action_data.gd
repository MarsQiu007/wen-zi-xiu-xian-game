extends RefCounted
class_name CombatActionData

const SNAPSHOT_VERSION := 1

var action_type: String = ""
var technique_id: String = ""
var item_id: String = ""
var target_index: int = 0


func to_dict() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"action_type": action_type,
		"technique_id": technique_id,
		"item_id": item_id,
		"target_index": target_index,
	}


static func from_dict(data: Dictionary) -> CombatActionData:
	var result := CombatActionData.new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result.action_type = str(data.get("action_type", ""))
	result.technique_id = str(data.get("technique_id", ""))
	result.item_id = str(data.get("item_id", ""))
	result.target_index = int(data.get("target_index", 0))
	return result

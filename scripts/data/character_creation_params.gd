extends RefCounted
class_name CharacterCreationParams

const SNAPSHOT_VERSION := 1

var character_name: String = ""
var morality_value: float = 0.0
var birth_region_id: StringName = &""
var opening_type: StringName = &"youth"
var difficulty: int = 1
var custom_seed: int = -1


func to_dict() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"character_name": character_name,
		"morality_value": morality_value,
		"birth_region_id": String(birth_region_id),
		"opening_type": String(opening_type),
		"difficulty": difficulty,
		"custom_seed": custom_seed,
	}


static func from_dict(data: Dictionary) -> CharacterCreationParams:
	var result := CharacterCreationParams.new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result.character_name = str(data.get("character_name", ""))
	result.morality_value = float(data.get("morality_value", 0.0))
	result.birth_region_id = StringName(str(data.get("birth_region_id", "")))
	result.opening_type = StringName(str(data.get("opening_type", "youth")))
	result.difficulty = int(data.get("difficulty", 1))
	result.custom_seed = int(data.get("custom_seed", -1))
	return result

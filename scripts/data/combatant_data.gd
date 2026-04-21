extends RefCounted
class_name CombatantData

const SNAPSHOT_VERSION := 1

var character_id: String = ""
var name: String = ""
var max_hp: int = 0
var current_hp: int = 0
var attack: int = 0
var defense: int = 0
var speed: int = 0
var equipped_techniques: Array[Dictionary] = []
var status_effects: Array[Dictionary] = []
var inventory_snapshot: Array[Dictionary] = []
var is_player: bool = false


func to_dict() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"character_id": character_id,
		"name": name,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"equipped_techniques": equipped_techniques.duplicate(true),
		"status_effects": status_effects.duplicate(true),
		"inventory_snapshot": inventory_snapshot.duplicate(true),
		"is_player": is_player,
	}


static func from_dict(data: Dictionary) -> CombatantData:
	var result := CombatantData.new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result.character_id = str(data.get("character_id", ""))
	result.name = str(data.get("name", ""))
	result.max_hp = int(data.get("max_hp", 0))
	result.current_hp = int(data.get("current_hp", 0))
	result.attack = int(data.get("attack", 0))
	result.defense = int(data.get("defense", 0))
	result.speed = int(data.get("speed", 0))
	result.equipped_techniques = (data.get("equipped_techniques", []) as Array).duplicate(true)
	result.status_effects = (data.get("status_effects", []) as Array).duplicate(true)
	result.inventory_snapshot = (data.get("inventory_snapshot", []) as Array).duplicate(true)
	result.is_player = bool(data.get("is_player", false))
	return result

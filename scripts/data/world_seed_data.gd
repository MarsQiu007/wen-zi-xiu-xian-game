extends RefCounted
class_name WorldSeedData

const SNAPSHOT_VERSION := 1

var seed_value: int = 0
var region_count: int = 7
var npc_count: int = 30
var resource_density: float = 0.5
var monster_density: float = 0.3


func to_dict() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"seed_value": seed_value,
		"region_count": region_count,
		"npc_count": npc_count,
		"resource_density": resource_density,
		"monster_density": monster_density,
	}


static func from_dict(data: Dictionary) -> WorldSeedData:
	var result := WorldSeedData.new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result.seed_value = int(data.get("seed_value", 0))
	result.region_count = int(data.get("region_count", 7))
	result.npc_count = int(data.get("npc_count", 30))
	result.resource_density = float(data.get("resource_density", 0.5))
	result.monster_density = float(data.get("monster_density", 0.3))
	return result

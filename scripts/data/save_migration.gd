extends RefCounted
class_name SaveMigration


static func v1_to_v2(data: Dictionary) -> Dictionary:
	var upgraded: Dictionary = data.duplicate(true)
	if not upgraded.has("creation_params"):
		upgraded["creation_params"] = {}
	if not upgraded.has("world_seed_data"):
		upgraded["world_seed_data"] = {}
	if not upgraded.has("relationship_network"):
		upgraded["relationship_network"] = {}
	if not upgraded.has("npc_memories"):
		upgraded["npc_memories"] = {}
	return upgraded

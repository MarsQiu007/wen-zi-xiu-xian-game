extends RefCounted
class_name SaveMigration


static func v1_to_v2(data: Dictionary) -> Dictionary:
	var upgraded: Dictionary = data.duplicate(true)
	if not upgraded.has("creation_params"):
		upgraded["creation_params"] = {}
	if not upgraded.has("world_seed") and upgraded.has("world_seed_data") and upgraded["world_seed_data"] is Dictionary:
		upgraded["world_seed"] = (upgraded["world_seed_data"] as Dictionary).duplicate(true)
	if not upgraded.has("world_seed"):
		upgraded["world_seed"] = {}
	if not upgraded.has("relationship_network"):
		upgraded["relationship_network"] = {}
	if not upgraded.has("memory_system") and upgraded.has("npc_memories") and upgraded["npc_memories"] is Dictionary:
		upgraded["memory_system"] = (upgraded["npc_memories"] as Dictionary).duplicate(true)
	if not upgraded.has("memory_system"):
		upgraded["memory_system"] = {}
	if not upgraded.has("npc_decision_intervals"):
		upgraded["npc_decision_intervals"] = {}

	var runtime_characters: Array = upgraded.get("runtime_characters", [])
	if runtime_characters is Array:
		var normalized_characters: Array = []
		for character_raw in runtime_characters:
			if not (character_raw is Dictionary):
				continue
			var character: Dictionary = (character_raw as Dictionary).duplicate(true)
			if not character.has("inventory") or not (character.get("inventory", null) is Array):
				character["inventory"] = []
			if not character.has("equipment") or not (character.get("equipment", null) is Dictionary):
				character["equipment"] = {}
			if not character.has("learned_techniques") or not (character.get("learned_techniques", null) is Array):
				character["learned_techniques"] = []
			if not character.has("technique_slots") or not (character.get("technique_slots", null) is Dictionary):
				character["technique_slots"] = {}
			if not character.has("combat_stats") or not (character.get("combat_stats", null) is Dictionary):
				character["combat_stats"] = _build_default_combat_stats(character)
			normalized_characters.append(character)
		upgraded["runtime_characters"] = normalized_characters

	var world_dynamics_data: Dictionary = {}
	if upgraded.has("world_dynamics_data") and upgraded["world_dynamics_data"] is Dictionary:
		world_dynamics_data = (upgraded["world_dynamics_data"] as Dictionary).duplicate(true)
	if not world_dynamics_data.has("version"):
		world_dynamics_data["version"] = 1
	var region_states_raw: Variant = world_dynamics_data.get("region_states", {})
	var normalized_region_states: Dictionary = {}
	if region_states_raw is Dictionary:
		for region_id_variant in (region_states_raw as Dictionary).keys():
			var region_id := str(region_id_variant).strip_edges()
			if region_id.is_empty():
				continue
			var state_raw: Variant = (region_states_raw as Dictionary).get(region_id_variant, {})
			if not (state_raw is Dictionary):
				state_raw = {}
			var state_data: Dictionary = (state_raw as Dictionary).duplicate(true)
			if not state_data.has("resource_stockpiles") or not (state_data.get("resource_stockpiles", null) is Dictionary):
				state_data["resource_stockpiles"] = {}
			if not state_data.has("production_rates") or not (state_data.get("production_rates", null) is Dictionary):
				state_data["production_rates"] = {}
			if not state_data.has("controlling_faction_id"):
				state_data["controlling_faction_id"] = ""
			normalized_region_states[region_id] = state_data
	world_dynamics_data["region_states"] = normalized_region_states
	if not world_dynamics_data.has("faction_influence") or not (world_dynamics_data.get("faction_influence", null) is Dictionary):
		world_dynamics_data["faction_influence"] = {}
	if not world_dynamics_data.has("fallback_world_rng") or not (world_dynamics_data.get("fallback_world_rng", null) is Dictionary):
		world_dynamics_data["fallback_world_rng"] = {"seed": _resolve_seed(upgraded), "state": 0}
	upgraded["world_dynamics_data"] = world_dynamics_data

	if not upgraded.has("inventory_data") or not (upgraded.get("inventory_data", null) is Dictionary):
		upgraded["inventory_data"] = {"inventories": {}}
	if not upgraded.has("technique_data") or not (upgraded.get("technique_data", null) is Dictionary):
		upgraded["technique_data"] = {
			"learned_techniques": {},
			"character_resources": {},
			"character_profiles": {},
		}
	if not upgraded.has("crafting_data") or not (upgraded.get("crafting_data", null) is Dictionary):
		upgraded["crafting_data"] = {"character_skills": {}}
	if not upgraded.has("rng_state") or not (upgraded.get("rng_state", null) is Dictionary):
		upgraded["rng_state"] = _build_rng_state_from_seed(_resolve_seed(upgraded))
	if not upgraded.has("snapshot_version"):
		upgraded["snapshot_version"] = 2
	return upgraded


static func _build_default_combat_stats(character: Dictionary) -> Dictionary:
	var cultivation_progress := float(character.get("cultivation_progress", 0.0))
	var max_hp := 120 + int(round(cultivation_progress))
	return {
		"max_hp": max_hp,
		"attack": 20 + int(round(cultivation_progress * 0.2)),
		"defense": 10 + int(round(cultivation_progress * 0.15)),
		"speed": 15 + int(round(cultivation_progress * 0.1)),
	}


static func _resolve_seed(data: Dictionary) -> int:
	var seed_value := int(data.get("seed", data.get("seed_value", 1)))
	if seed_value == 0:
		seed_value = 1
	return seed_value


static func _build_rng_state_from_seed(seed_value: int) -> Dictionary:
	var resolved_seed := seed_value
	if resolved_seed == 0:
		resolved_seed = 1
	var rng_channels := preload("res://scripts/core/rng_channels.gd").new()
	rng_channels.seed_all(resolved_seed)
	return rng_channels.save_state()

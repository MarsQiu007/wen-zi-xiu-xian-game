extends RefCounted
class_name HumanCultivationGate

const OPPORTUNITY_CONTACT_THRESHOLD := 4
const SECT_TECHNIQUE_CONTACT_BONUS := 1

const TechniqueServiceScript = preload("res://scripts/services/technique_service.gd")


static func apply_action(runtime: Dictionary, action_id: String, action_def: Dictionary) -> Dictionary:
	var next_runtime: Dictionary = runtime.duplicate(true)
	var player: Dictionary = (next_runtime.get("player", {}) as Dictionary).duplicate(true)
	var gate_source: Variant = player.get("cultivation_gate", next_runtime.get("cultivation_gate", {}))
	var gate: Dictionary = gate_source.duplicate(true) if gate_source is Dictionary else {}
	var is_active_contact := bool(action_def.get("active_contact", false))
	var contact_gain := int(action_def.get("contact_gain", 0)) if is_active_contact else 0
	var is_faith_contact := bool(action_def.get("faith_contact", false))
	var faith_contact_gain := int(action_def.get("faith_contact_gain", 0)) if is_faith_contact else 0
	var orthodox_suspicion_gain := int(action_def.get("orthodox_suspicion_gain", 0)) if is_faith_contact else 0
	var sect_technique_bonus := _resolve_sect_technique_contact_bonus(next_runtime, player)
	if is_active_contact:
		contact_gain += sect_technique_bonus
	if is_faith_contact:
		faith_contact_gain += sect_technique_bonus
	var unlocked_before := bool(gate.get("opportunity_unlocked", false))
	if is_active_contact:
		gate["has_active_contact"] = true
		gate["contact_score"] = int(gate.get("contact_score", 0)) + contact_gain
		gate["last_contact_action"] = action_id
	if is_faith_contact:
		gate["faith_contact_score"] = int(gate.get("faith_contact_score", 0)) + faith_contact_gain
		if sect_technique_bonus > 0:
			gate["contact_score"] = int(gate.get("contact_score", 0)) + sect_technique_bonus
		gate["orthodox_suspicion"] = int(gate.get("orthodox_suspicion", 0)) + orthodox_suspicion_gain
		gate["last_faith_action"] = action_id
		gate["faith_marked"] = int(gate.get("faith_contact_score", 0)) >= 2
		if _has_sect_technique_access(player):
			gate["faith_sect_technique_chance"] = true
			gate["faith_sect_technique_candidate"] = _pick_faith_sect_technique(next_runtime, player)
	gate["opportunity_unlocked"] = (
		(bool(gate.get("has_active_contact", false)) and int(gate.get("contact_score", 0)) >= OPPORTUNITY_CONTACT_THRESHOLD)
		or (
			is_faith_contact
			and sect_technique_bonus > 0
			and int(gate.get("faith_contact_score", 0)) >= 2
		)
	)
	var learned_on_unlock := false
	if bool(gate.get("opportunity_unlocked", false)) and not unlocked_before:
		learned_on_unlock = _trigger_unlock_learn(next_runtime, player, gate)
	if not player.is_empty():
		player["cultivation_gate"] = gate.duplicate(true)
		next_runtime["player"] = player
		var player_id := str(player.get("id", ""))
		if not player_id.is_empty():
			var registry: Dictionary = (next_runtime.get("character_registry", {}) as Dictionary).duplicate(true)
			registry[player_id] = player.duplicate(true)
			next_runtime["character_registry"] = registry
	next_runtime["cultivation_gate"] = gate
	return {
		"runtime": next_runtime,
		"contact_gain": contact_gain,
		"faith_contact_gain": faith_contact_gain,
		"orthodox_suspicion_gain": orthodox_suspicion_gain,
		"sect_technique_bonus": sect_technique_bonus,
		"learned_on_unlock": learned_on_unlock,
		"unlocked_now": bool(gate.get("opportunity_unlocked", false)) and not unlocked_before,
	}


static func _resolve_sect_technique_contact_bonus(runtime: Dictionary, player: Dictionary) -> int:
	if not _has_owned_sect_technique(runtime, player):
		return 0
	return SECT_TECHNIQUE_CONTACT_BONUS


static func _has_sect_technique_access(player: Dictionary) -> bool:
	var faction_id := str(player.get("faction_id", "")).strip_edges()
	return not faction_id.is_empty()


static func _has_owned_sect_technique(runtime: Dictionary, player: Dictionary) -> bool:
	var catalog: Variant = runtime.get("catalog", null)
	if not (catalog is WorldDataCatalog):
		return false
	var faction_id := str(player.get("faction_id", "")).strip_edges()
	if faction_id.is_empty():
		return false
	var learned_raw: Variant = player.get("learned_techniques", [])
	if not (learned_raw is Array):
		return false
	for learned_raw_entry in learned_raw:
		if not (learned_raw_entry is Dictionary):
			continue
		var technique_id := str((learned_raw_entry as Dictionary).get("technique_id", "")).strip_edges()
		if technique_id.is_empty():
			continue
		var technique: Resource = (catalog as WorldDataCatalog).find_technique(StringName(technique_id))
		if technique == null:
			continue
		if str(_resource_get(technique, "sect_exclusive_id", "")).strip_edges() == faction_id:
			return true
	return false


static func _pick_faith_sect_technique(runtime: Dictionary, player: Dictionary) -> String:
	var catalog: Variant = runtime.get("catalog", null)
	if not (catalog is WorldDataCatalog):
		return ""
	var faction_id := str(player.get("faction_id", "")).strip_edges()
	if faction_id.is_empty():
		return ""
	var techniques_raw: Variant = (catalog as WorldDataCatalog).get("techniques")
	if not (techniques_raw is Array):
		return ""
	for technique_raw in techniques_raw:
		if not (technique_raw is Resource):
			continue
		var technique: Resource = technique_raw
		if str(_resource_get(technique, "sect_exclusive_id", "")).strip_edges() != faction_id:
			continue
		var technique_id := str(_resource_get(technique, "id", "")).strip_edges()
		if not technique_id.is_empty():
			return technique_id
	return ""


static func _trigger_unlock_learn(runtime: Dictionary, player: Dictionary, gate: Dictionary) -> bool:
	var technique_service := _resolve_technique_service(runtime)
	if technique_service == null:
		return false
	var catalog: Variant = runtime.get("catalog", null)
	if not (catalog is WorldDataCatalog):
		return false
	var player_id := str(player.get("id", "")).strip_edges()
	if player_id.is_empty():
		return false
	var sect_technique_id := str(gate.get("faith_sect_technique_candidate", "")).strip_edges()
	if sect_technique_id.is_empty():
		sect_technique_id = _pick_faith_sect_technique(runtime, player)
	if sect_technique_id.is_empty():
		return false
	technique_service.set_character_profile(player_id, {
		"faction_id": str(player.get("faction_id", "")),
		"realm": int((runtime.get("cultivation_state", {}) as Dictionary).get("stage_index", 0)),
	})
	var learn_result: Dictionary = technique_service.learn_technique(player_id, sect_technique_id, catalog as WorldDataCatalog)
	gate["unlock_learn_attempted"] = true
	gate["unlock_learn_technique_id"] = sect_technique_id
	gate["unlock_learn_success"] = bool(learn_result.get("success", false))
	gate["unlock_learn_reason"] = str(learn_result.get("reason", ""))
	_sync_player_techniques_from_service(runtime, player, technique_service)
	return bool(learn_result.get("success", false))


static func _resolve_technique_service(runtime: Dictionary) -> TechniqueService:
	var existing: Variant = runtime.get("technique_service", null)
	if existing is TechniqueService:
		return existing as TechniqueService
	var created: TechniqueService = TechniqueServiceScript.new()
	var catalog: Variant = runtime.get("catalog", null)
	if catalog is WorldDataCatalog:
		created.bind_catalog(catalog as WorldDataCatalog)
	runtime["technique_service"] = created
	return created


static func _sync_player_techniques_from_service(runtime: Dictionary, player: Dictionary, technique_service: TechniqueService) -> void:
	var player_id := str(player.get("id", "")).strip_edges()
	if player_id.is_empty():
		return
	var learned_techniques: Array[Dictionary] = technique_service.get_learned_techniques(player_id)
	if learned_techniques.is_empty():
		return
	player["learned_techniques"] = learned_techniques.duplicate(true)
	runtime["player"] = player.duplicate(true)
	var registry: Dictionary = (runtime.get("character_registry", {}) as Dictionary).duplicate(true)
	if registry.has(player_id):
		var registry_player: Dictionary = (registry.get(player_id, {}) as Dictionary).duplicate(true)
		registry_player["learned_techniques"] = learned_techniques.duplicate(true)
		registry[player_id] = registry_player
		runtime["character_registry"] = registry


static func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value

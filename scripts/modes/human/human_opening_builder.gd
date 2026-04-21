extends RefCounted
class_name HumanOpeningBuilder

const DEFAULT_CHARACTER_ID := &"mvp_village_heir"
const DEFAULT_REGION_ID := &"mvp_village_region"
const DEFAULT_FAMILY_ID := &"mvp_lin_family"
const DEFAULT_FACTION_ID := &"mvp_village_settlement"
const DEFAULT_SECT_ID := &"mvp_small_sect"

const DEFAULT_EQUIPMENT := {
	"weapon": null,
	"head": null,
	"body": null,
	"accessory_1": null,
	"accessory_2": null,
}

const DEFAULT_TECHNIQUE_SLOTS := {
	"martial_1": null,
	"spirit_1": null,
	"ultimate": null,
	"movement": null,
	"passive_1": null,
	"passive_2": null,
}

const DEFAULT_COMBAT_STATS := {
	"max_hp": 100,
	"attack": 10,
	"defense": 5,
	"speed": 10,
}

const OPENING_STARTER_LOADOUTS := {
	"youth": {
		"inventory": [
			{"item_id": "mvp_item_basic_healing_pill", "quantity": 1, "rarity": "common", "affixes": [], "equipped_slot": ""},
		],
		"learned_techniques": [],
		"technique_slots": {},
	},
	"young_adult": {
		"inventory": [
			{"item_id": "mvp_item_iron_sword", "quantity": 1, "rarity": "common", "affixes": [], "equipped_slot": "weapon", "durability": 30},
			{"item_id": "mvp_item_basic_healing_pill", "quantity": 2, "rarity": "common", "affixes": [], "equipped_slot": ""},
		],
		"learned_techniques": [
			{"technique_id": "mvp_technique_basic_sword", "mastery_level": 0, "unlocked_affixes": [], "locked_affixes": [], "equipped_slot": "martial_1"},
		],
		"technique_slots": {"martial_1": "mvp_technique_basic_sword"},
	},
	"adult": {
		"inventory": [
			{"item_id": "mvp_item_iron_sword", "quantity": 1, "rarity": "common", "affixes": [], "equipped_slot": "weapon", "durability": 30},
			{"item_id": "mvp_item_fire_spirit_robe", "quantity": 1, "rarity": "uncommon", "affixes": [], "equipped_slot": "body", "durability": 35},
		],
		"learned_techniques": [
			{"technique_id": "mvp_technique_basic_sword", "mastery_level": 10, "unlocked_affixes": [], "locked_affixes": [], "equipped_slot": "martial_1"},
			{"technique_id": "mvp_technique_iron_body", "mastery_level": 10, "unlocked_affixes": [], "locked_affixes": [], "equipped_slot": "passive_1"},
		],
		"technique_slots": {"martial_1": "mvp_technique_basic_sword", "passive_1": "mvp_technique_iron_body"},
	},
	"warrior": {
		"inventory": [
			{"item_id": "mvp_item_iron_sword", "quantity": 1, "rarity": "common", "affixes": [], "equipped_slot": "weapon", "durability": 32},
			{"item_id": "mvp_item_fire_spirit_robe", "quantity": 1, "rarity": "uncommon", "affixes": [], "equipped_slot": "body", "durability": 36},
		],
		"learned_techniques": [
			{"technique_id": "mvp_technique_basic_sword", "mastery_level": 15, "unlocked_affixes": [], "locked_affixes": [], "equipped_slot": "martial_1"},
		],
		"technique_slots": {"martial_1": "mvp_technique_basic_sword"},
	},
}

const OPENING_PRESETS := {
	"youth": {
		"label": "少年",
		"age_years": 14,
		"life_stage": "youth",
		"strategy": "learning",
		"default_action_plan": [
			"study_classics",
			"support_family",
			"study_classics",
			"seek_master",
			"visit_sect",
			"ask_for_guidance",
			"study_classics",
			"support_family",
		],
		"branch_weights": {
			"survival": 0,
			"family": 1,
			"learning": 6,
			"cultivation": 2,
		},
		"pressures": {
			"survival": 3,
			"family": 4,
			"learning": 8,
			"cultivation": 5,
		},
	},
	"young_adult": {
		"label": "青年",
		"age_years": 18,
		"life_stage": "young_adult",
		"strategy": "family",
		"branch_weights": {
			"survival": 1,
			"family": 6,
			"learning": 0,
			"cultivation": 1,
		},
		"pressures": {
			"survival": 5,
			"family": 8,
			"learning": 3,
			"cultivation": 4,
		},
	},
	"adult": {
		"label": "成年",
		"age_years": 26,
		"life_stage": "adult",
		"strategy": "survival",
		"branch_weights": {
			"survival": 5,
			"family": 1,
			"learning": 0,
			"cultivation": 0,
		},
		"pressures": {
			"survival": 8,
			"family": 6,
			"learning": 1,
			"cultivation": 2,
		},
	},
	"warrior": {
		"label": "武者",
		"age_years": 20,
		"life_stage": "adult",
		"strategy": "survival",
		"branch_weights": {
			"survival": 6,
			"family": 1,
			"learning": 0,
			"cultivation": 1,
		},
		"pressures": {
			"survival": 7,
			"family": 5,
			"learning": 1,
			"cultivation": 3,
		},
	},
}


static func normalize_opening_type(opening_type: String) -> String:
	var lowered := opening_type.to_lower()
	match lowered:
		"少年", "shaonian", "youth":
			return "youth"
		"青年", "qingnian", "young", "young_adult":
			return "young_adult"
		"成年", "chengnian", "adult":
			return "adult"
		"武者", "战士", "warrior":
			return "warrior"
		_:
			return "youth"


static func build_opening(catalog: Resource, opening_type: String, options: Dictionary = {}) -> Dictionary:
	var normalized := normalize_opening_type(opening_type)
	var preset: Dictionary = OPENING_PRESETS.get(normalized, OPENING_PRESETS["youth"])
	var base_character := _pick_base_character(catalog)
	var base_character_id := str(_resource_get(base_character, "id", ""))
	var strategy := str(options.get("strategy", ""))
	if strategy.is_empty():
		strategy = str(preset.get("strategy", "learning"))
	var branch_weights: Dictionary = (preset.get("branch_weights", {}) as Dictionary).duplicate(true)
	if strategy == "active_cultivation":
		branch_weights["cultivation"] = int(branch_weights.get("cultivation", 0)) + 8
		branch_weights["learning"] = maxi(0, int(branch_weights.get("learning", 0)) - 2)
	var action_plan := _normalize_action_plan(options.get("action_plan", []))
	if action_plan.is_empty() and not options.has("strategy") and not options.has("action_plan"):
		action_plan = _normalize_action_plan(preset.get("default_action_plan", []))
	var base_player := {
		"id": str(options.get("player_id", str(_resource_get(base_character, "id", "human_player")))),
		"display_name": str(options.get("player_name", str(_resource_get(base_character, "display_name", "凡俗主角")))),
		"base_character_id": base_character_id,
		"age_years": int(options.get("age_years", int(preset.get("age_years", 14)))),
		"life_stage": str(preset.get("life_stage", normalized)),
		"region_id": str(options.get("region_id", str(_resource_get(base_character, "region_id", str(DEFAULT_REGION_ID))))),
		"family_id": str(options.get("family_id", str(_resource_get(base_character, "family_id", str(DEFAULT_FAMILY_ID))))),
		"faction_id": str(options.get("faction_id", str(_resource_get(base_character, "faction_id", str(DEFAULT_FACTION_ID))))),
		"sect_id": str(options.get("sect_id", str(DEFAULT_SECT_ID))),
		"spouse_character_id": str(options.get("spouse_character_id", str(_resource_get(base_character, "spouse_character_id", "")))),
		"dao_companion_character_id": str(options.get("dao_companion_character_id", str(_resource_get(base_character, "dao_companion_character_id", "")))),
		"direct_line_child_ids": _coerce_string_array(options.get("direct_line_child_ids", _resource_get(base_character, "direct_line_child_ids", PackedStringArray()))),
		"legal_heir_character_id": str(options.get("legal_heir_character_id", str(_resource_get(base_character, "legal_heir_character_id", "")))),
		"inheritance_priority": int(options.get("inheritance_priority", int(_resource_get(base_character, "inheritance_priority", 0)))),
		"is_alive": true,
	}
	base_player = _normalize_runtime_character(base_player, options, catalog, normalized, true)
	var registry := _build_character_registry(catalog, options, base_player, normalized)
	var current_player_id := str(options.get("current_player_id", str(base_player.get("id", "human_player"))))
	var player: Dictionary = base_player.duplicate(true)
	if registry.has(current_player_id):
		player = (registry[current_player_id] as Dictionary).duplicate(true)
	var player_gate: Dictionary = (player.get("cultivation_gate", {}) as Dictionary).duplicate(true)
	var player_state: Dictionary = (player.get("cultivation_state", {}) as Dictionary).duplicate(true)
	return {
		"opening_type": normalized,
		"opening_label": str(preset.get("label", "少年")),
		"player": player,
		"current_player_id": str(player.get("id", current_player_id)),
		"character_registry": registry,
		"lineage": {
			"active_character_id": str(player.get("id", current_player_id)),
			"founding_character_id": str(base_player.get("id", "human_player")),
			"inheritance_rule": str(options.get("inheritance_rule", _resolve_inheritance_rule(catalog, str(player.get("family_id", ""))))),
			"last_death": {},
			"terminated": false,
			"termination_reason": "",
			"perspective_history": [str(player.get("id", current_player_id))],
		},
		"pressures": (preset.get("pressures", {}) as Dictionary).duplicate(true),
		"branch_weights": branch_weights,
		"dominant_branch": strategy,
		"cultivation_gate": player_gate,
		"cultivation_state": player_state,
		"recent_actions": [],
		"strategy": strategy,
		"action_plan": action_plan,
		"forced_death_day": int(options.get("forced_death_day", 0)),
		"day_count": 0,
	}


static func _pick_base_character(catalog: Resource) -> Resource:
	if catalog != null and catalog.has_method("find_character"):
		var by_id: Resource = catalog.find_character(DEFAULT_CHARACTER_ID)
		if by_id != null:
			return by_id
	if catalog == null:
		return null
	var characters: Array = catalog.get("characters") if catalog.has_method("get") else []
	for character in characters:
		if character != null:
			return character
	return null


static func _normalize_action_plan(raw_plan: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_plan is Array:
		for action_id in raw_plan:
			result.append(str(action_id))
	return result


static func _build_character_registry(catalog: Resource, options: Dictionary, base_player: Dictionary, opening_type: String) -> Dictionary:
	var registry: Dictionary = {}
	if catalog != null:
		var characters: Array = catalog.get("characters") if catalog.has_method("get") else []
		for character in characters:
			if character == null:
				continue
			var character_id := str(_resource_get(character, "id", ""))
			if character_id.is_empty():
				continue
			registry[character_id] = {
				"id": character_id,
				"display_name": str(_resource_get(character, "display_name", "无名氏")),
				"base_character_id": character_id,
				"age_years": int(_resource_get(character, "age_years", 0)),
				"life_stage": str(_resource_get(character, "life_stage", "ordinary")),
				"region_id": str(_resource_get(character, "region_id", "")),
				"family_id": str(_resource_get(character, "family_id", "")),
				"faction_id": str(_resource_get(character, "faction_id", "")),
				"sect_id": str(options.get("sect_id", str(DEFAULT_SECT_ID))),
				"spouse_character_id": str(_resource_get(character, "spouse_character_id", "")),
				"dao_companion_character_id": str(_resource_get(character, "dao_companion_character_id", "")),
				"direct_line_child_ids": _coerce_string_array(_resource_get(character, "direct_line_child_ids", PackedStringArray())),
				"legal_heir_character_id": str(_resource_get(character, "legal_heir_character_id", "")),
				"inheritance_priority": int(_resource_get(character, "inheritance_priority", 0)),
				"is_alive": true,
			}
			registry[character_id] = _normalize_runtime_character(registry[character_id], options, catalog, opening_type, false)
	registry[str(base_player.get("id", "human_player"))] = base_player.duplicate(true)
	var runtime_characters: Variant = options.get("runtime_characters", [])
	if runtime_characters is Array:
		for raw_character in runtime_characters:
			if not (raw_character is Dictionary):
				continue
			var character_id := str(raw_character.get("id", ""))
			if character_id.is_empty():
				continue
			var existing: Dictionary = (registry.get(character_id, {}) as Dictionary).duplicate(true)
			for key in raw_character.keys():
				existing[key] = raw_character[key]
			existing["id"] = character_id
			existing["display_name"] = str(existing.get("display_name", character_id))
			existing["base_character_id"] = str(existing.get("base_character_id", character_id))
			existing["sect_id"] = str(existing.get("sect_id", str(options.get("sect_id", str(DEFAULT_SECT_ID)))))
			existing["spouse_character_id"] = str(existing.get("spouse_character_id", ""))
			existing["dao_companion_character_id"] = str(existing.get("dao_companion_character_id", ""))
			existing["direct_line_child_ids"] = _coerce_string_array(existing.get("direct_line_child_ids", []))
			existing["legal_heir_character_id"] = str(existing.get("legal_heir_character_id", ""))
			existing["inheritance_priority"] = int(existing.get("inheritance_priority", 0))
			existing["is_alive"] = bool(existing.get("is_alive", true))
			var should_apply_loadout := character_id == str(base_player.get("id", ""))
			registry[character_id] = _normalize_runtime_character(existing, options, catalog, opening_type, should_apply_loadout)
	return registry


static func _normalize_runtime_character(character: Dictionary, options: Dictionary, catalog: Resource, opening_type: String, apply_starting_loadout: bool) -> Dictionary:
	var normalized: Dictionary = character.duplicate(true)
	normalized["cultivation_gate"] = _normalize_cultivation_gate(normalized.get("cultivation_gate", options.get("cultivation_gate", {})))
	normalized["cultivation_state"] = _normalize_cultivation_state(normalized, normalized.get("cultivation_state", options.get("cultivation_state", {})))
	_normalize_player_runtime_extensions(normalized, catalog, opening_type, options, apply_starting_loadout)
	return normalized


static func _normalize_player_runtime_extensions(character: Dictionary, catalog: Resource, opening_type: String, options: Dictionary, apply_starting_loadout: bool) -> void:
	var loadout := _build_starting_loadout(catalog, opening_type)
	var inventory_source: Variant = character.get("inventory", options.get("inventory", []))
	var learned_source: Variant = character.get("learned_techniques", options.get("learned_techniques", []))
	if apply_starting_loadout and inventory_source is Array and (inventory_source as Array).is_empty():
		inventory_source = loadout.get("inventory", [])
	if apply_starting_loadout and learned_source is Array and (learned_source as Array).is_empty():
		learned_source = loadout.get("learned_techniques", [])

	var normalized_inventory := _normalize_inventory_records(inventory_source)
	var normalized_learned := _normalize_learned_techniques(learned_source)

	var equipment_source: Variant = character.get("equipment", options.get("equipment", {}))
	if apply_starting_loadout and (not (equipment_source is Dictionary) or (equipment_source as Dictionary).is_empty()):
		equipment_source = _derive_equipment_from_inventory(normalized_inventory)
	var normalized_equipment := _normalize_equipment(equipment_source)
	if apply_starting_loadout:
		_apply_equipment_to_inventory(normalized_inventory, normalized_equipment)

	var technique_slots_source: Variant = character.get("technique_slots", options.get("technique_slots", {}))
	if apply_starting_loadout and (not (technique_slots_source is Dictionary) or (technique_slots_source as Dictionary).is_empty()):
		technique_slots_source = _derive_technique_slots_from_learned(normalized_learned)
	var normalized_slots := _normalize_technique_slots(technique_slots_source)
	if apply_starting_loadout:
		_apply_technique_slots_to_learned(normalized_learned, normalized_slots)

	var base_stats_source: Variant = character.get("combat_stats_base", character.get("combat_stats", options.get("combat_stats", DEFAULT_COMBAT_STATS)))
	var base_stats := _normalize_combat_stats(base_stats_source)

	character["inventory"] = normalized_inventory
	character["equipment"] = normalized_equipment
	character["learned_techniques"] = normalized_learned
	character["technique_slots"] = normalized_slots
	character["combat_stats_base"] = base_stats
	character["combat_stats"] = _build_combat_stats(base_stats, normalized_inventory, normalized_learned, catalog)


static func _build_starting_loadout(catalog: Resource, opening_type: String) -> Dictionary:
	var preset: Dictionary = OPENING_STARTER_LOADOUTS.get(opening_type, OPENING_STARTER_LOADOUTS.get("youth", {}))
	var inventory := _normalize_inventory_records(preset.get("inventory", []))
	var learned := _normalize_learned_techniques(preset.get("learned_techniques", []))
	var slots := _normalize_technique_slots(preset.get("technique_slots", {}))

	var filtered_inventory: Array[Dictionary] = []
	for record in inventory:
		var item_id := str(record.get("item_id", ""))
		if _catalog_has_item(catalog, item_id):
			filtered_inventory.append(record)

	var filtered_learned: Array[Dictionary] = []
	for technique in learned:
		var technique_id := str(technique.get("technique_id", ""))
		if _catalog_has_technique(catalog, technique_id):
			filtered_learned.append(technique)

	_apply_technique_slots_to_learned(filtered_learned, slots)
	var equipment := _derive_equipment_from_inventory(filtered_inventory)
	_apply_equipment_to_inventory(filtered_inventory, equipment)

	return {
		"inventory": filtered_inventory,
		"equipment": equipment,
		"learned_techniques": filtered_learned,
		"technique_slots": _derive_technique_slots_from_learned(filtered_learned),
	}


static func _normalize_inventory_records(raw_inventory: Variant) -> Array[Dictionary]:
	if not (raw_inventory is Array):
		return []
	var result: Array[Dictionary] = []
	for raw_record in raw_inventory:
		if not (raw_record is Dictionary):
			continue
		var item_id := str(raw_record.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			continue
		var quantity := maxi(0, int(raw_record.get("quantity", 0)))
		if quantity <= 0:
			continue
		var normalized := {
			"item_id": item_id,
			"quantity": quantity,
			"rarity": str(raw_record.get("rarity", "common")),
			"affixes": _normalize_affixes(raw_record.get("affixes", [])),
			"equipped_slot": str(raw_record.get("equipped_slot", "")).strip_edges(),
		}
		if raw_record.has("durability"):
			normalized["durability"] = maxi(0, int(raw_record.get("durability", 0)))
		if raw_record.has("daily_decay"):
			normalized["daily_decay"] = maxi(0, int(raw_record.get("daily_decay", 0)))
		if raw_record.has("auto_decay"):
			normalized["auto_decay"] = bool(raw_record.get("auto_decay", false))
		result.append(normalized)
	return result


static func _normalize_affixes(raw_affixes: Variant) -> Array[Dictionary]:
	if not (raw_affixes is Array):
		return []
	var normalized: Array[Dictionary] = []
	for affix in raw_affixes:
		if affix is Dictionary:
			normalized.append((affix as Dictionary).duplicate(true))
	return normalized


static func _normalize_learned_techniques(raw_learned: Variant) -> Array[Dictionary]:
	if not (raw_learned is Array):
		return []
	var result: Array[Dictionary] = []
	for raw_record in raw_learned:
		if not (raw_record is Dictionary):
			continue
		var technique_id := str(raw_record.get("technique_id", "")).strip_edges()
		if technique_id.is_empty():
			continue
		result.append({
			"technique_id": technique_id,
			"mastery_level": clampi(int(raw_record.get("mastery_level", 0)), 0, 100),
			"unlocked_affixes": _normalize_affixes(raw_record.get("unlocked_affixes", [])),
			"locked_affixes": _normalize_affixes(raw_record.get("locked_affixes", [])),
			"equipped_slot": str(raw_record.get("equipped_slot", "")).strip_edges(),
		})
	return result


static func _normalize_equipment(raw_equipment: Variant) -> Dictionary:
	var equipment := DEFAULT_EQUIPMENT.duplicate(true)
	if raw_equipment is Dictionary:
		for slot in equipment.keys():
			var value: Variant = (raw_equipment as Dictionary).get(slot, null)
			if value == null:
				equipment[slot] = null
			else:
				equipment[slot] = str(value)
	return equipment


static func _normalize_technique_slots(raw_slots: Variant) -> Dictionary:
	var slots := DEFAULT_TECHNIQUE_SLOTS.duplicate(true)
	if raw_slots is Dictionary:
		for slot in slots.keys():
			var value: Variant = (raw_slots as Dictionary).get(slot, null)
			if value == null:
				slots[slot] = null
			else:
				slots[slot] = str(value)
	return slots


static func _normalize_combat_stats(raw_stats: Variant) -> Dictionary:
	var stats := DEFAULT_COMBAT_STATS.duplicate(true)
	if raw_stats is Dictionary:
		for key in stats.keys():
			stats[key] = maxi(0, int((raw_stats as Dictionary).get(key, stats[key])))
	return stats


static func _derive_equipment_from_inventory(inventory: Array[Dictionary]) -> Dictionary:
	var equipment := DEFAULT_EQUIPMENT.duplicate(true)
	for record in inventory:
		var slot := str(record.get("equipped_slot", "")).strip_edges()
		if slot.is_empty() or not equipment.has(slot):
			continue
		equipment[slot] = str(record.get("item_id", ""))
	return equipment


static func _apply_equipment_to_inventory(inventory: Array[Dictionary], equipment: Dictionary) -> void:
	for index in range(inventory.size()):
		var record: Dictionary = inventory[index]
		var item_id := str(record.get("item_id", ""))
		var next_slot := ""
		for slot_variant in equipment.keys():
			var equipped_item_id := str(equipment.get(slot_variant, ""))
			if item_id == equipped_item_id:
				next_slot = str(slot_variant)
				break
		record["equipped_slot"] = next_slot
		inventory[index] = record


static func _derive_technique_slots_from_learned(learned_techniques: Array[Dictionary]) -> Dictionary:
	var slots := DEFAULT_TECHNIQUE_SLOTS.duplicate(true)
	for record in learned_techniques:
		var slot := str(record.get("equipped_slot", "")).strip_edges()
		if slot.is_empty() or not slots.has(slot):
			continue
		slots[slot] = str(record.get("technique_id", ""))
	return slots


static func _apply_technique_slots_to_learned(learned_techniques: Array[Dictionary], technique_slots: Dictionary) -> void:
	for index in range(learned_techniques.size()):
		var record: Dictionary = learned_techniques[index]
		var technique_id := str(record.get("technique_id", ""))
		var matched_slot := ""
		for slot_variant in technique_slots.keys():
			var slot_technique_id := str(technique_slots.get(slot_variant, ""))
			if technique_id == slot_technique_id:
				matched_slot = str(slot_variant)
				break
		record["equipped_slot"] = matched_slot
		learned_techniques[index] = record


static func _build_combat_stats(base_stats: Dictionary, inventory: Array[Dictionary], learned_techniques: Array[Dictionary], catalog: Resource) -> Dictionary:
	var stats := _normalize_combat_stats(base_stats)
	var equip_bonus := _collect_equipment_bonus(inventory, catalog)
	var technique_bonus := _collect_technique_bonus(learned_techniques, catalog)
	stats["attack"] = maxi(0, int(stats.get("attack", 10)) + int(equip_bonus.get("attack", 0.0)) + int(technique_bonus.get("attack", 0.0)))
	stats["defense"] = maxi(0, int(stats.get("defense", 5)) + int(equip_bonus.get("defense", 0.0)) + int(technique_bonus.get("defense", 0.0)))
	stats["speed"] = maxi(0, int(stats.get("speed", 10)) + int(equip_bonus.get("speed", 0.0)) + int(technique_bonus.get("speed", 0.0)))
	stats["max_hp"] = maxi(1, int(stats.get("max_hp", 100)) + int(equip_bonus.get("max_hp", 0.0)) + int(technique_bonus.get("max_hp", 0.0)))
	return stats


static func _collect_equipment_bonus(inventory: Array[Dictionary], catalog: Resource) -> Dictionary:
	var total := {"attack": 0.0, "defense": 0.0, "speed": 0.0, "max_hp": 0.0}
	for record in inventory:
		var slot := str(record.get("equipped_slot", "")).strip_edges()
		if slot.is_empty():
			continue
		var item_id := str(record.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			continue
		var item_data: Resource = null
		if catalog != null and catalog.has_method("find_item"):
			item_data = catalog.find_item(StringName(item_id))
		if item_data != null:
			_accumulate_stat_effects(total, _resource_get(item_data, "stat_modifiers", {}))
		_accumulate_affix_effects(total, record.get("affixes", []))
	return total


static func _collect_technique_bonus(learned_techniques: Array[Dictionary], catalog: Resource) -> Dictionary:
	var total := {"attack": 0.0, "defense": 0.0, "speed": 0.0, "max_hp": 0.0}
	for record in learned_techniques:
		var slot := str(record.get("equipped_slot", "")).strip_edges()
		if slot.is_empty():
			continue
		var technique_id := str(record.get("technique_id", "")).strip_edges()
		if technique_id.is_empty() or catalog == null or not catalog.has_method("find_technique"):
			continue
		var technique: Resource = catalog.find_technique(StringName(technique_id))
		if technique == null:
			continue
		_accumulate_stat_effects(total, _resource_get(technique, "base_effects", {}))
		var unlocked_affixes := _normalize_affixes(record.get("unlocked_affixes", []))
		for affix in unlocked_affixes:
			_accumulate_stat_effects(total, affix.get("effect", affix))
	return total


static func _accumulate_affix_effects(total: Dictionary, raw_affixes: Variant) -> void:
	if not (raw_affixes is Array):
		return
	for raw_affix in raw_affixes:
		if not (raw_affix is Dictionary):
			continue
		var affix: Dictionary = raw_affix
		var effect: Variant = affix.get("effect", affix)
		_accumulate_stat_effects(total, effect)


static func _accumulate_stat_effects(total: Dictionary, raw_effect: Variant) -> void:
	if not (raw_effect is Dictionary):
		return
	for key_variant in (raw_effect as Dictionary).keys():
		var value: Variant = (raw_effect as Dictionary)[key_variant]
		if not (value is int or value is float):
			continue
		var key := str(key_variant)
		match key:
			"attack", "attack_bonus", "atk", "atk_bonus":
				total["attack"] = float(total.get("attack", 0.0)) + float(value)
			"defense", "defense_bonus":
				total["defense"] = float(total.get("defense", 0.0)) + float(value)
			"speed", "speed_bonus", "agility", "agility_bonus":
				total["speed"] = float(total.get("speed", 0.0)) + float(value)
			"max_hp", "max_hp_bonus", "hp", "hp_bonus":
				total["max_hp"] = float(total.get("max_hp", 0.0)) + float(value)


static func _catalog_has_item(catalog: Resource, item_id: String) -> bool:
	if item_id.is_empty() or catalog == null or not catalog.has_method("find_item"):
		return false
	return catalog.find_item(StringName(item_id)) != null


static func _catalog_has_technique(catalog: Resource, technique_id: String) -> bool:
	if technique_id.is_empty() or catalog == null or not catalog.has_method("find_technique"):
		return false
	return catalog.find_technique(StringName(technique_id)) != null


static func _normalize_cultivation_gate(raw_gate: Variant) -> Dictionary:
	var source: Dictionary = raw_gate.duplicate(true) if raw_gate is Dictionary else {}
	return {
		"contact_score": int(source.get("contact_score", 0)),
		"has_active_contact": bool(source.get("has_active_contact", false)),
		"opportunity_unlocked": bool(source.get("opportunity_unlocked", false)),
		"last_contact_action": str(source.get("last_contact_action", "")),
		"faith_contact_score": int(source.get("faith_contact_score", 0)),
		"orthodox_suspicion": int(source.get("orthodox_suspicion", 0)),
		"last_faith_action": str(source.get("last_faith_action", "")),
		"faith_marked": bool(source.get("faith_marked", false)),
	}


static func _normalize_cultivation_state(character: Dictionary, raw_state: Variant) -> Dictionary:
	var source: Dictionary = raw_state.duplicate(true) if raw_state is Dictionary else {}
	var age_years := int(character.get("age_years", 14))
	var lifespan_limit := int(source.get("lifespan_limit_years", maxi(60, age_years + 40)))
	var lifespan_remaining := int(source.get("lifespan_remaining_years", maxi(0, lifespan_limit - age_years)))
	return {
		"realm": str(source.get("realm", "mortal")),
		"realm_label": str(source.get("realm_label", "凡体")),
		"stage_index": int(source.get("stage_index", 0)),
		"progress": int(source.get("progress", 0)),
		"progress_to_next": int(source.get("progress_to_next", 2)),
		"practice_days": int(source.get("practice_days", 0)),
		"breakthrough_attempts": int(source.get("breakthrough_attempts", 0)),
		"setback_count": int(source.get("setback_count", 0)),
		"weakness_days": int(source.get("weakness_days", 0)),
		"lifespan_limit_years": lifespan_limit,
		"lifespan_remaining_years": lifespan_remaining,
		"last_breakthrough_outcome": str(source.get("last_breakthrough_outcome", "")),
		"last_failure_reason": str(source.get("last_failure_reason", "")),
		"last_event": str(source.get("last_event", "")),
	}


static func _resolve_inheritance_rule(catalog: Resource, family_id: String) -> String:
	if catalog == null or family_id.is_empty() or not catalog.has_method("find_family"):
		return "direct_descendant_first"
	var family: Resource = catalog.find_family(StringName(family_id))
	return str(_resource_get(family, "inheritance_rule", "direct_descendant_first"))


static func _coerce_string_array(raw_value: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_value is PackedStringArray:
		for item in raw_value:
			result.append(str(item))
	elif raw_value is Array:
		for item in raw_value:
			result.append(str(item))
	return result


static func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	return fallback if value == null else value

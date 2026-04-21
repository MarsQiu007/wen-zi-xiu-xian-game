extends RefCounted
class_name HumanModeRuntime

const HumanOpeningBuilderScript = preload("res://scripts/modes/human/human_opening_builder.gd")
const HumanEarlyLoopScript = preload("res://scripts/modes/human/human_early_loop.gd")

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

const DEFAULT_EQUIPMENT_DURABILITY := 30
const DEFAULT_EQUIPMENT_DAILY_DECAY := 1
const DEFAULT_CONSUMABLE_DAILY_DECAY := 1


func build_initial_state(catalog: Resource, options: Dictionary = {}) -> Dictionary:
	var opening_type := str(options.get("opening_type", "youth"))
	return HumanOpeningBuilderScript.build_opening(catalog, opening_type, options)


func advance_day(runtime: Dictionary, simulated_day: int) -> Dictionary:
	var resolved_catalog: Resource = _resolve_catalog(runtime)
	var normalized_runtime := _normalize_player_runtime(runtime, resolved_catalog)
	var next_runtime := HumanEarlyLoopScript.advance_day(normalized_runtime, simulated_day)
	var runtime_result: Dictionary = next_runtime.get("runtime", normalized_runtime).duplicate(true)
	_normalize_player_runtime(runtime_result, resolved_catalog)
	_apply_daily_item_decay(runtime_result)
	_rebuild_player_combat_stats(runtime_result, resolved_catalog)
	next_runtime["runtime"] = runtime_result
	return next_runtime


func _resolve_catalog(runtime: Dictionary) -> Resource:
	var catalog: Variant = runtime.get("catalog", null)
	if catalog is Resource:
		return catalog
	return null


func _normalize_player_runtime(runtime: Dictionary, catalog: Resource) -> Dictionary:
	var player: Dictionary = (runtime.get("player", {}) as Dictionary).duplicate(true)
	if player.is_empty():
		return runtime

	var inventory := _normalize_inventory(player.get("inventory", []))
	var equipment := _normalize_equipment(player.get("equipment", {}))
	_apply_equipment_to_inventory(inventory, equipment)

	var learned_techniques := _normalize_learned_techniques(player.get("learned_techniques", []))
	var technique_slots := _normalize_technique_slots(player.get("technique_slots", {}))
	_apply_technique_slots_to_learned(learned_techniques, technique_slots)

	var combat_stats_base := _normalize_combat_stats(player.get("combat_stats_base", player.get("combat_stats", DEFAULT_COMBAT_STATS)))

	player["inventory"] = inventory
	player["equipment"] = equipment
	player["learned_techniques"] = learned_techniques
	player["technique_slots"] = technique_slots
	player["combat_stats_base"] = combat_stats_base
	player["combat_stats"] = _build_combat_stats(combat_stats_base, inventory, learned_techniques, catalog)

	runtime["player"] = player
	runtime["catalog"] = catalog if catalog != null else runtime.get("catalog", null)
	return runtime


func _normalize_inventory(raw_inventory: Variant) -> Array[Dictionary]:
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


func _normalize_affixes(raw_affixes: Variant) -> Array[Dictionary]:
	if not (raw_affixes is Array):
		return []
	var result: Array[Dictionary] = []
	for affix in raw_affixes:
		if affix is Dictionary:
			result.append((affix as Dictionary).duplicate(true))
	return result


func _normalize_equipment(raw_equipment: Variant) -> Dictionary:
	var equipment := DEFAULT_EQUIPMENT.duplicate(true)
	if raw_equipment is Dictionary:
		for slot in equipment.keys():
			var value: Variant = (raw_equipment as Dictionary).get(slot, null)
			if value == null:
				equipment[slot] = null
			else:
				equipment[slot] = str(value)
	return equipment


func _normalize_learned_techniques(raw_learned: Variant) -> Array[Dictionary]:
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


func _normalize_technique_slots(raw_slots: Variant) -> Dictionary:
	var slots := DEFAULT_TECHNIQUE_SLOTS.duplicate(true)
	if raw_slots is Dictionary:
		for slot in slots.keys():
			var value: Variant = (raw_slots as Dictionary).get(slot, null)
			if value == null:
				slots[slot] = null
			else:
				slots[slot] = str(value)
	return slots


func _normalize_combat_stats(raw_stats: Variant) -> Dictionary:
	var stats := DEFAULT_COMBAT_STATS.duplicate(true)
	if raw_stats is Dictionary:
		for key in stats.keys():
			stats[key] = maxi(0, int((raw_stats as Dictionary).get(key, stats[key])))
	return stats


func _apply_equipment_to_inventory(inventory: Array[Dictionary], equipment: Dictionary) -> void:
	for index in range(inventory.size()):
		var record: Dictionary = inventory[index]
		var item_id := str(record.get("item_id", "")).strip_edges()
		var matched_slot := ""
		for slot_variant in equipment.keys():
			if str(equipment.get(slot_variant, "")) == item_id:
				matched_slot = str(slot_variant)
				break
		record["equipped_slot"] = matched_slot
		inventory[index] = record


func _apply_technique_slots_to_learned(learned_techniques: Array[Dictionary], technique_slots: Dictionary) -> void:
	for index in range(learned_techniques.size()):
		var record: Dictionary = learned_techniques[index]
		var technique_id := str(record.get("technique_id", "")).strip_edges()
		var matched_slot := ""
		for slot_variant in technique_slots.keys():
			if str(technique_slots.get(slot_variant, "")) == technique_id:
				matched_slot = str(slot_variant)
				break
		record["equipped_slot"] = matched_slot
		learned_techniques[index] = record


func _build_combat_stats(base_stats: Dictionary, inventory: Array[Dictionary], learned_techniques: Array[Dictionary], catalog: Resource) -> Dictionary:
	var stats := _normalize_combat_stats(base_stats)
	var equip_bonus := _collect_equipment_bonus(inventory, catalog)
	var technique_bonus := _collect_technique_bonus(learned_techniques, catalog)
	stats["attack"] = maxi(0, int(stats.get("attack", 10)) + int(equip_bonus.get("attack", 0.0)) + int(technique_bonus.get("attack", 0.0)))
	stats["defense"] = maxi(0, int(stats.get("defense", 5)) + int(equip_bonus.get("defense", 0.0)) + int(technique_bonus.get("defense", 0.0)))
	stats["speed"] = maxi(0, int(stats.get("speed", 10)) + int(equip_bonus.get("speed", 0.0)) + int(technique_bonus.get("speed", 0.0)))
	stats["max_hp"] = maxi(1, int(stats.get("max_hp", 100)) + int(equip_bonus.get("max_hp", 0.0)) + int(technique_bonus.get("max_hp", 0.0)))
	return stats


func _collect_equipment_bonus(inventory: Array[Dictionary], catalog: Resource) -> Dictionary:
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


func _collect_technique_bonus(learned_techniques: Array[Dictionary], catalog: Resource) -> Dictionary:
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
		for affix in _normalize_affixes(record.get("unlocked_affixes", [])):
			_accumulate_stat_effects(total, affix.get("effect", affix))
	return total


func _accumulate_affix_effects(total: Dictionary, raw_affixes: Variant) -> void:
	if not (raw_affixes is Array):
		return
	for raw_affix in raw_affixes:
		if not (raw_affix is Dictionary):
			continue
		var affix: Dictionary = raw_affix
		_accumulate_stat_effects(total, affix.get("effect", affix))


func _accumulate_stat_effects(total: Dictionary, raw_effect: Variant) -> void:
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


func _apply_daily_item_decay(runtime: Dictionary) -> void:
	var player: Dictionary = (runtime.get("player", {}) as Dictionary).duplicate(true)
	if player.is_empty():
		return
	var inventory := _normalize_inventory(player.get("inventory", []))
	var equipment := _normalize_equipment(player.get("equipment", {}))
	var updated_inventory: Array[Dictionary] = []
	for record in inventory:
		var next_record: Dictionary = record.duplicate(true)
		var quantity := int(next_record.get("quantity", 0))
		var equipped_slot := str(next_record.get("equipped_slot", "")).strip_edges()
		if quantity <= 0:
			continue

		var has_durability := next_record.has("durability") or not equipped_slot.is_empty()
		if has_durability:
			var decay := int(next_record.get("daily_decay", DEFAULT_EQUIPMENT_DAILY_DECAY))
			var current_durability := int(next_record.get("durability", DEFAULT_EQUIPMENT_DURABILITY))
			current_durability = maxi(0, current_durability - maxi(0, decay))
			next_record["durability"] = current_durability
			if current_durability <= 0:
				if not equipped_slot.is_empty() and equipment.has(equipped_slot):
					equipment[equipped_slot] = null
				continue

		if bool(next_record.get("auto_decay", false)):
			var consume_decay := int(next_record.get("daily_decay", DEFAULT_CONSUMABLE_DAILY_DECAY))
			var next_quantity := maxi(0, quantity - maxi(0, consume_decay))
			next_record["quantity"] = next_quantity
			if next_quantity <= 0:
				continue
		updated_inventory.append(next_record)

	for slot_variant in equipment.keys():
		var equipped_item_id := str(equipment.get(slot_variant, "")).strip_edges()
		if equipped_item_id.is_empty():
			equipment[slot_variant] = null
			continue
		var still_exists := false
		for record in updated_inventory:
			if str(record.get("item_id", "")) == equipped_item_id and str(record.get("equipped_slot", "")) == str(slot_variant):
				still_exists = true
				break
		if not still_exists:
			equipment[slot_variant] = null

	player["inventory"] = updated_inventory
	player["equipment"] = equipment
	runtime["player"] = player


func _rebuild_player_combat_stats(runtime: Dictionary, catalog: Resource) -> void:
	var player: Dictionary = (runtime.get("player", {}) as Dictionary).duplicate(true)
	if player.is_empty():
		return
	var combat_stats_base := _normalize_combat_stats(player.get("combat_stats_base", player.get("combat_stats", DEFAULT_COMBAT_STATS)))
	var inventory := _normalize_inventory(player.get("inventory", []))
	var learned_techniques := _normalize_learned_techniques(player.get("learned_techniques", []))
	player["combat_stats_base"] = combat_stats_base
	player["combat_stats"] = _build_combat_stats(combat_stats_base, inventory, learned_techniques, catalog)
	runtime["player"] = player


func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value

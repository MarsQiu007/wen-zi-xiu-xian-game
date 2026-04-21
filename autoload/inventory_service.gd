extends Node

const EventContractsScript = preload("res://scripts/core/event_contracts.gd")

const SLOT_WEAPON := "weapon"
const SLOT_HEAD := "head"
const SLOT_BODY := "body"
const SLOT_ACCESSORY_1 := "accessory_1"
const SLOT_ACCESSORY_2 := "accessory_2"

var _catalog: Resource
var _inventories: Dictionary = {}
var _event_log_node: Node


func bind_catalog(catalog: Resource) -> void:
	_catalog = catalog


func add_item(character_id: String, item_id: String, quantity: int, rarity: String, affixes: Array) -> bool:
	var resolved_character_id := character_id.strip_edges()
	var resolved_item_id := item_id.strip_edges()
	if resolved_character_id.is_empty() or resolved_item_id.is_empty() or quantity <= 0:
		return false

	var inventory := _get_or_create_inventory(resolved_character_id)
	var normalized_affixes := _normalize_affixes(affixes)
	for index in range(inventory.size()):
		var record: Dictionary = inventory[index]
		if str(record.get("item_id", "")) != resolved_item_id:
			continue
		if str(record.get("equipped_slot", "")) != "":
			continue
		if str(record.get("rarity", "")) != rarity:
			continue
		if not _affixes_equal(record.get("affixes", []), normalized_affixes):
			continue
		record["quantity"] = int(record.get("quantity", 0)) + quantity
		inventory[index] = record
		_inventories[resolved_character_id] = inventory
		_emit_inventory_event(EventContractsScript.ITEM_ACQUIRED, {
			"character_id": resolved_character_id,
			"item_id": resolved_item_id,
			"quantity": quantity,
			"rarity": rarity,
			"stacked": true,
		})
		return true

	inventory.append(_build_record(resolved_item_id, quantity, rarity, normalized_affixes, ""))
	_inventories[resolved_character_id] = inventory
	_emit_inventory_event(EventContractsScript.ITEM_ACQUIRED, {
		"character_id": resolved_character_id,
		"item_id": resolved_item_id,
		"quantity": quantity,
		"rarity": rarity,
		"stacked": false,
	})
	return true


func remove_item(character_id: String, item_id: String, quantity: int) -> bool:
	var resolved_character_id := character_id.strip_edges()
	var resolved_item_id := item_id.strip_edges()
	if resolved_character_id.is_empty() or resolved_item_id.is_empty() or quantity <= 0:
		return false
	if not _inventories.has(resolved_character_id):
		return false

	var inventory: Array[Dictionary] = _inventories[resolved_character_id]
	var total := 0
	for record in inventory:
		if str(record.get("item_id", "")) == resolved_item_id:
			total += int(record.get("quantity", 0))
	if total < quantity:
		return false

	var remaining := quantity
	for index in range(inventory.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var record: Dictionary = inventory[index]
		if str(record.get("item_id", "")) != resolved_item_id:
			continue
		var current := int(record.get("quantity", 0))
		if current <= remaining:
			remaining -= current
			inventory.remove_at(index)
		else:
			record["quantity"] = current - remaining
			remaining = 0
			inventory[index] = record

	if inventory.is_empty():
		_inventories.erase(resolved_character_id)
	else:
		_inventories[resolved_character_id] = inventory

	_emit_inventory_event(EventContractsScript.ITEM_DROPPED, {
		"character_id": resolved_character_id,
		"item_id": resolved_item_id,
		"quantity": quantity,
	})
	return true


func get_inventory(character_id: String) -> Array[Dictionary]:
	var resolved_character_id := character_id.strip_edges()
	if resolved_character_id.is_empty() or not _inventories.has(resolved_character_id):
		return []
	return _duplicate_inventory(_inventories[resolved_character_id])


func equip_item(character_id: String, item_id: String, slot: String) -> bool:
	var resolved_character_id := character_id.strip_edges()
	var resolved_item_id := item_id.strip_edges()
	var resolved_slot := slot.strip_edges()
	if resolved_character_id.is_empty() or resolved_item_id.is_empty() or resolved_slot.is_empty():
		return false
	if not _inventories.has(resolved_character_id):
		return false
	if not _is_known_slot(resolved_slot):
		return false

	var item_def := _find_item_data(resolved_item_id)
	if item_def == null:
		return false
	var default_slot := str(_resource_get(item_def, "equip_slot", ""))
	if not default_slot.is_empty() and default_slot != resolved_slot:
		return false

	var inventory: Array[Dictionary] = _inventories[resolved_character_id]
	var target_index := -1
	for index in range(inventory.size()):
		var record: Dictionary = inventory[index]
		if str(record.get("item_id", "")) != resolved_item_id:
			continue
		if str(record.get("equipped_slot", "")) != "":
			continue
		if int(record.get("quantity", 0)) <= 0:
			continue
		target_index = index
		break
	if target_index == -1:
		return false

	_unequip_slot_in_inventory(inventory, resolved_slot)

	var target_record: Dictionary = inventory[target_index]
	var target_quantity := int(target_record.get("quantity", 0))
	if target_quantity <= 0:
		return false
	if target_quantity > 1:
		target_record["quantity"] = target_quantity - 1
		inventory[target_index] = target_record
		inventory.append(_build_record(
			resolved_item_id,
			1,
			str(target_record.get("rarity", "common")),
			target_record.get("affixes", []),
			resolved_slot
		))
	else:
		target_record["equipped_slot"] = resolved_slot
		inventory[target_index] = target_record

	_inventories[resolved_character_id] = inventory
	_emit_inventory_event(EventContractsScript.ITEM_EQUIPPED, {
		"character_id": resolved_character_id,
		"item_id": resolved_item_id,
		"slot": resolved_slot,
		"equipped": true,
	})
	return true


func unequip_item(character_id: String, slot: String) -> bool:
	var resolved_character_id := character_id.strip_edges()
	var resolved_slot := slot.strip_edges()
	if resolved_character_id.is_empty() or resolved_slot.is_empty() or not _inventories.has(resolved_character_id):
		return false

	var inventory: Array[Dictionary] = _inventories[resolved_character_id]
	var item_id := ""
	var changed := false
	for index in range(inventory.size()):
		var record: Dictionary = inventory[index]
		if str(record.get("equipped_slot", "")) != resolved_slot:
			continue
		item_id = str(record.get("item_id", ""))
		record["equipped_slot"] = ""
		inventory[index] = record
		changed = true
		break
	if not changed:
		return false

	_merge_unequipped_stacks(inventory)
	_inventories[resolved_character_id] = inventory
	_emit_inventory_event(EventContractsScript.ITEM_EQUIPPED, {
		"character_id": resolved_character_id,
		"item_id": item_id,
		"slot": resolved_slot,
		"equipped": false,
	})
	return true


func use_consumable(character_id: String, item_id: String) -> Dictionary:
	var resolved_character_id := character_id.strip_edges()
	var resolved_item_id := item_id.strip_edges()
	if resolved_character_id.is_empty() or resolved_item_id.is_empty() or not _inventories.has(resolved_character_id):
		return {}

	var item_def := _find_item_data(resolved_item_id)
	if item_def == null:
		return {}
	if str(_resource_get(item_def, "item_type", "")) != "consumable":
		return {}

	var inventory: Array[Dictionary] = _inventories[resolved_character_id]
	for index in range(inventory.size()):
		var record: Dictionary = inventory[index]
		if str(record.get("item_id", "")) != resolved_item_id:
			continue
		if str(record.get("equipped_slot", "")) != "":
			continue
		var current := int(record.get("quantity", 0))
		if current <= 0:
			continue
		if current == 1:
			inventory.remove_at(index)
		else:
			record["quantity"] = current - 1
			inventory[index] = record
		if inventory.is_empty():
			_inventories.erase(resolved_character_id)
		else:
			_inventories[resolved_character_id] = inventory

		var effect := _duplicate_dict(_resource_get(item_def, "consumable_effect", {}))
		_emit_inventory_event(EventContractsScript.ITEM_USED, {
			"character_id": resolved_character_id,
			"item_id": resolved_item_id,
			"effect": effect,
		})
		return effect

	return {}


func get_equipped_stats(character_id: String) -> Dictionary:
	var resolved_character_id := character_id.strip_edges()
	if resolved_character_id.is_empty() or not _inventories.has(resolved_character_id):
		return {}

	var total: Dictionary = {}
	var inventory: Array[Dictionary] = _inventories[resolved_character_id]
	for record in inventory:
		if str(record.get("equipped_slot", "")).is_empty():
			continue
		var item_id := StringName(str(record.get("item_id", "")))
		var item_def: Resource = null
		if _catalog != null and _catalog.has_method("find_item"):
			item_def = _catalog.find_item(item_id)
		if item_def != null:
			_accumulate_numeric_dict(total, _resource_get(item_def, "stat_modifiers", {}))
		_accumulate_affix_effects(total, record.get("affixes", []))
	return total


func has_item(character_id: String, item_id: String, min_quantity: int) -> bool:
	if min_quantity <= 0:
		return true
	var resolved_character_id := character_id.strip_edges()
	var resolved_item_id := item_id.strip_edges()
	if resolved_character_id.is_empty() or resolved_item_id.is_empty() or not _inventories.has(resolved_character_id):
		return false

	var count := 0
	for record in _inventories[resolved_character_id]:
		if str(record.get("item_id", "")) != resolved_item_id:
			continue
		count += int(record.get("quantity", 0))
		if count >= min_quantity:
			return true
	return false


func save_state() -> Dictionary:
	var serialized: Dictionary = {}
	for character_id_variant in _inventories.keys():
		var character_id := str(character_id_variant)
		serialized[character_id] = _duplicate_inventory(_inventories[character_id_variant])
	return {
		"inventories": serialized,
	}


func load_state(d: Dictionary) -> void:
	_inventories.clear()
	var raw_inventories: Variant = d.get("inventories", {})
	if not (raw_inventories is Dictionary):
		return

	for character_id_variant in raw_inventories.keys():
		var character_id := str(character_id_variant)
		if character_id.is_empty():
			continue
		var raw_list: Variant = raw_inventories[character_id_variant]
		if not (raw_list is Array):
			continue
		var normalized_list: Array[Dictionary] = []
		for raw_record in raw_list:
			if not (raw_record is Dictionary):
				continue
			var normalized_record := _normalize_record(raw_record)
			if normalized_record.is_empty():
				continue
			normalized_list.append(normalized_record)
		if not normalized_list.is_empty():
			_inventories[character_id] = normalized_list


func _get_or_create_inventory(character_id: String) -> Array[Dictionary]:
	if not _inventories.has(character_id):
		var empty_inventory: Array[Dictionary] = []
		_inventories[character_id] = empty_inventory
		return empty_inventory

	var raw_inventory: Variant = _inventories[character_id]
	if raw_inventory is Array:
		var normalized_inventory: Array[Dictionary] = []
		for record in raw_inventory:
			if record is Dictionary:
				normalized_inventory.append(record)
		_inventories[character_id] = normalized_inventory
		return normalized_inventory

	var reset_inventory: Array[Dictionary] = []
	_inventories[character_id] = reset_inventory
	return reset_inventory


func _build_record(item_id: String, quantity: int, rarity: String, affixes: Variant, equipped_slot: String) -> Dictionary:
	return {
		"item_id": item_id,
		"quantity": quantity,
		"rarity": rarity,
		"affixes": _normalize_affixes(affixes),
		"equipped_slot": equipped_slot,
	}


func _normalize_record(raw_record: Dictionary) -> Dictionary:
	var item_id := str(raw_record.get("item_id", "")).strip_edges()
	if item_id.is_empty():
		return {}
	var quantity := int(raw_record.get("quantity", 0))
	if quantity <= 0:
		return {}
	return _build_record(
		item_id,
		quantity,
		str(raw_record.get("rarity", "common")),
		raw_record.get("affixes", []),
		str(raw_record.get("equipped_slot", ""))
	)


func _duplicate_inventory(source: Variant) -> Array[Dictionary]:
	if not (source is Array):
		return []
	var result: Array[Dictionary] = []
	for record in source:
		if record is Dictionary:
			result.append((record as Dictionary).duplicate(true))
	return result


func _normalize_affixes(raw_affixes: Variant) -> Array[Dictionary]:
	if not (raw_affixes is Array):
		return []
	var normalized: Array[Dictionary] = []
	for affix in raw_affixes:
		if affix is Dictionary:
			normalized.append((affix as Dictionary).duplicate(true))
	return normalized


func _affixes_equal(a: Variant, b: Variant) -> bool:
	return var_to_str(_normalize_affixes(a)) == var_to_str(_normalize_affixes(b))


func _is_known_slot(slot: String) -> bool:
	return slot == SLOT_WEAPON or slot == SLOT_HEAD or slot == SLOT_BODY or slot == SLOT_ACCESSORY_1 or slot == SLOT_ACCESSORY_2


func _find_item_data(item_id: String) -> Resource:
	if _catalog == null or not _catalog.has_method("find_item"):
		return null
	return _catalog.find_item(StringName(item_id))


func _unequip_slot_in_inventory(inventory: Array[Dictionary], slot: String) -> void:
	for index in range(inventory.size()):
		var record: Dictionary = inventory[index]
		if str(record.get("equipped_slot", "")) != slot:
			continue
		record["equipped_slot"] = ""
		inventory[index] = record
	_merge_unequipped_stacks(inventory)


func _merge_unequipped_stacks(inventory: Array[Dictionary]) -> void:
	var merged: Array[Dictionary] = []
	for record in inventory:
		var equipped_slot := str(record.get("equipped_slot", ""))
		if not equipped_slot.is_empty():
			merged.append(record)
			continue

		var merged_index := -1
		for index in range(merged.size()):
			var existing: Dictionary = merged[index]
			if str(existing.get("equipped_slot", "")) != "":
				continue
			if str(existing.get("item_id", "")) != str(record.get("item_id", "")):
				continue
			if str(existing.get("rarity", "")) != str(record.get("rarity", "")):
				continue
			if not _affixes_equal(existing.get("affixes", []), record.get("affixes", [])):
				continue
			merged_index = index
			break
		if merged_index == -1:
			merged.append(record)
		else:
			var target: Dictionary = merged[merged_index]
			target["quantity"] = int(target.get("quantity", 0)) + int(record.get("quantity", 0))
			merged[merged_index] = target

	inventory.clear()
	for record in merged:
		inventory.append(record)


func _accumulate_numeric_dict(total: Dictionary, value: Variant) -> void:
	if not (value is Dictionary):
		return
	for key_variant in (value as Dictionary).keys():
		var entry = value[key_variant]
		if entry is int or entry is float:
			var key := str(key_variant)
			total[key] = float(total.get(key, 0.0)) + float(entry)


func _accumulate_affix_effects(total: Dictionary, raw_affixes: Variant) -> void:
	if not (raw_affixes is Array):
		return
	for raw_affix in raw_affixes:
		if not (raw_affix is Dictionary):
			continue
		var affix: Dictionary = raw_affix
		var effect: Variant = affix.get("effect")
		if effect is Dictionary:
			_accumulate_numeric_dict(total, effect)
		else:
			_accumulate_numeric_dict(total, affix)


func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value


func _event_log() -> Node:
	if is_instance_valid(_event_log_node):
		return _event_log_node
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return null
	_event_log_node = get_tree().root.get_node_or_null("EventLog")
	return _event_log_node


func _emit_inventory_event(event_name: StringName, trace: Dictionary) -> void:
	var event_log := _event_log()
	if event_log == null or not event_log.has_method("add_event"):
		return
	event_log.add_event({
		"category": "inventory",
		"title": str(event_name),
		"direct_cause": str(event_name),
		"result": "inventory_event",
		"trace": _duplicate_dict(trace),
	})


func _duplicate_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

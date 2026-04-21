extends RefCounted
class_name CraftingService

const EventContractsScript = preload("res://scripts/core/event_contracts.gd")

const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
const RECIPE_TYPE_ALCHEMY := "alchemy"
const RECIPE_TYPE_FORGE := "forge"
const FAILURE_MATERIAL_LOSS_RATIO := 0.5

const REASON_OK := "OK"
const REASON_INVALID_CHARACTER := "INVALID_CHARACTER"
const REASON_RECIPE_NOT_FOUND := "RECIPE_NOT_FOUND"
const REASON_INVALID_RECIPE := "INVALID_RECIPE"
const REASON_INSUFFICIENT_MATERIALS := "INSUFFICIENT_MATERIALS"
const REASON_INSUFFICIENT_SKILL_LEVEL := "INSUFFICIENT_SKILL_LEVEL"
const REASON_CRAFTING_FAILURE := "CRAFTING_FAILURE"
const REASON_INVENTORY_UNAVAILABLE := "INVENTORY_UNAVAILABLE"

var _catalog: Resource
var _event_log: Node
var _rng_channels: RefCounted
var _inventory_service: Node
var _character_skills: Dictionary = {}


func bind_catalog(catalog: Resource) -> void:
	_catalog = catalog


func bind_event_log(event_log: Node) -> void:
	_event_log = event_log


func bind_rng_channels(rng_channels: RefCounted) -> void:
	_rng_channels = rng_channels


func bind_inventory_service(inventory_service: Node) -> void:
	_inventory_service = inventory_service


func set_character_skill_level(character_id: String, recipe_type: String, level: int) -> void:
	var resolved_character_id := character_id.strip_edges()
	var resolved_recipe_type := recipe_type.strip_edges().to_lower()
	if resolved_character_id.is_empty() or resolved_recipe_type.is_empty():
		return
	if not _is_supported_recipe_type(resolved_recipe_type):
		return
	var skill_data := _get_or_create_character_skill_data(resolved_character_id)
	skill_data[resolved_recipe_type] = maxi(0, level)
	_character_skills[resolved_character_id] = skill_data


func get_character_skill_level(character_id: String, recipe_type: String) -> int:
	var resolved_character_id := character_id.strip_edges()
	var resolved_recipe_type := recipe_type.strip_edges().to_lower()
	if resolved_character_id.is_empty() or resolved_recipe_type.is_empty():
		return 0
	if not _is_supported_recipe_type(resolved_recipe_type):
		return 0
	var skill_data := _get_or_create_character_skill_data(resolved_character_id)
	return maxi(0, int(skill_data.get(resolved_recipe_type, 1)))


func craft_item(character_id: String, recipe_id: String, catalog: WorldDataCatalog, rng: SeededRandom) -> Dictionary:
	var resolved_character_id := character_id.strip_edges()
	var resolved_recipe_id := recipe_id.strip_edges()
	if resolved_character_id.is_empty() or resolved_recipe_id.is_empty():
		return _result(false, REASON_INVALID_CHARACTER)

	_catalog = catalog
	var recipe := _find_recipe(catalog, resolved_recipe_id)
	if recipe == null:
		return _result(false, REASON_RECIPE_NOT_FOUND)

	var normalized_recipe := _normalize_recipe(recipe)
	if normalized_recipe.is_empty():
		return _result(false, REASON_INVALID_RECIPE)

	var inventory_service := _resolve_inventory_service()
	if inventory_service == null:
		return _result(false, REASON_INVENTORY_UNAVAILABLE)

	var required_skill_level := int(normalized_recipe.get("required_skill_level", 0))
	var recipe_type := str(normalized_recipe.get("recipe_type", ""))
	var skill_level := get_character_skill_level(resolved_character_id, recipe_type)
	if skill_level < required_skill_level:
		return _result(false, REASON_INSUFFICIENT_SKILL_LEVEL, {
			"required_skill_level": required_skill_level,
			"skill_level": skill_level,
			"recipe_type": recipe_type,
		})

	var materials: Array[Dictionary] = normalized_recipe.get("materials", [])
	for material in materials:
		var material_item_id := str(material.get("item_id", ""))
		var required_quantity := int(material.get("quantity", 0))
		if required_quantity <= 0:
			continue
		if not bool(inventory_service.has_method("has_item")):
			return _result(false, REASON_INVENTORY_UNAVAILABLE)
		if not bool(inventory_service.has_item(resolved_character_id, material_item_id, required_quantity)):
			return _result(false, REASON_INSUFFICIENT_MATERIALS, {
				"missing_item_id": material_item_id,
				"required_quantity": required_quantity,
			})

	var material_quality_score := _calculate_material_quality_score(resolved_character_id, materials, inventory_service)
	var success_rate := _compute_success_rate(
		float(normalized_recipe.get("success_rate_base", 0.0)),
		material_quality_score,
		str(normalized_recipe.get("result_rarity_min", "common")),
		skill_level,
		required_skill_level
	)
	var roll := _roll_float(_resolve_loot_rng(rng))
	if roll > success_rate:
		var materials_lost := _consume_materials_on_failure(resolved_character_id, materials, inventory_service)
		_emit_event(EventContractsScript.CRAFTING_FAILURE, {
			"character_id": resolved_character_id,
			"recipe_id": resolved_recipe_id,
			"roll": roll,
			"success_rate": success_rate,
			"materials_lost": _duplicate_array_dict(materials_lost),
		})
		return _result(false, REASON_CRAFTING_FAILURE, {
			"materials_lost": materials_lost,
			"roll": roll,
			"success_rate": success_rate,
		})

	var consumed_materials := _consume_materials_on_success(resolved_character_id, materials, inventory_service)
	var output_rarity := _compute_output_rarity(
		material_quality_score,
		str(normalized_recipe.get("result_rarity_min", "common")),
		skill_level,
		required_skill_level,
		_resolve_loot_rng(rng)
	)
	var crafted_item_id := str(normalized_recipe.get("result_item_id", ""))
	var crafted_quantity := int(normalized_recipe.get("result_quantity", 1))
	if crafted_quantity <= 0:
		crafted_quantity = 1

	if not bool(inventory_service.has_method("add_item")):
		return _result(false, REASON_INVENTORY_UNAVAILABLE)
	var add_ok := bool(inventory_service.add_item(
		resolved_character_id,
		crafted_item_id,
		crafted_quantity,
		output_rarity,
		[]
	))
	if not add_ok:
		return _result(false, REASON_INVENTORY_UNAVAILABLE)

	var success_trace := {
		"character_id": resolved_character_id,
		"recipe_id": resolved_recipe_id,
		"item_id": crafted_item_id,
		"quantity": crafted_quantity,
		"rarity": output_rarity,
		"consumed_materials": _duplicate_array_dict(consumed_materials),
		"material_quality_score": material_quality_score,
		"success_rate": success_rate,
		"roll": roll,
	}
	_emit_event(EventContractsScript.CRAFTING_SUCCESS, success_trace)
	_emit_event(EventContractsScript.ITEM_CRAFTED, success_trace)

	return _result(true, REASON_OK, {
		"crafted_item_id": crafted_item_id,
		"crafted_quantity": crafted_quantity,
		"crafted_rarity": output_rarity,
		"consumed_materials": consumed_materials,
		"material_quality_score": material_quality_score,
		"success_rate": success_rate,
		"roll": roll,
	})


func get_available_recipes(character_id: String, catalog: WorldDataCatalog) -> Array[Resource]:
	var resolved_character_id := character_id.strip_edges()
	if resolved_character_id.is_empty():
		return []
	_catalog = catalog
	var inventory_service := _resolve_inventory_service()
	if inventory_service == null:
		return []
	if catalog == null:
		return []

	var result: Array[Resource] = []
	var recipes_raw: Variant = catalog.get("recipes")
	if not (recipes_raw is Array):
		return result

	for recipe_raw in recipes_raw:
		if not (recipe_raw is Resource):
			continue
		var recipe: Resource = recipe_raw
		var normalized_recipe := _normalize_recipe(recipe)
		if normalized_recipe.is_empty():
			continue
		var recipe_type := str(normalized_recipe.get("recipe_type", ""))
		var required_skill_level := int(normalized_recipe.get("required_skill_level", 0))
		if get_character_skill_level(resolved_character_id, recipe_type) < required_skill_level:
			continue

		var can_craft := true
		var materials: Array[Dictionary] = normalized_recipe.get("materials", [])
		for material in materials:
			var material_item_id := str(material.get("item_id", ""))
			var required_quantity := int(material.get("quantity", 0))
			if required_quantity <= 0:
				continue
			if not bool(inventory_service.has_method("has_item")):
				can_craft = false
				break
			if not bool(inventory_service.has_item(resolved_character_id, material_item_id, required_quantity)):
				can_craft = false
				break
		if can_craft:
			result.append(recipe)

	return result


func get_recipe_details(recipe_id: String, catalog: WorldDataCatalog) -> Dictionary:
	var resolved_recipe_id := recipe_id.strip_edges()
	if resolved_recipe_id.is_empty():
		return {}
	_catalog = catalog
	var recipe := _find_recipe(catalog, resolved_recipe_id)
	if recipe == null:
		return {}
	var normalized_recipe := _normalize_recipe(recipe)
	if normalized_recipe.is_empty():
		return {}

	return {
		"recipe_id": resolved_recipe_id,
		"recipe_type": str(normalized_recipe.get("recipe_type", "")),
		"result_item_id": str(normalized_recipe.get("result_item_id", "")),
		"result_quantity": int(normalized_recipe.get("result_quantity", 1)),
		"result_rarity_min": str(normalized_recipe.get("result_rarity_min", "common")),
		"materials": _duplicate_array_dict(normalized_recipe.get("materials", [])),
		"required_skill_level": int(normalized_recipe.get("required_skill_level", 0)),
		"success_rate_base": float(normalized_recipe.get("success_rate_base", 0.0)),
	}


func save_state() -> Dictionary:
	var serialized_skills: Dictionary = {}
	for character_id_variant in _character_skills.keys():
		var character_id := str(character_id_variant)
		if character_id.is_empty():
			continue
		var raw_skill_data: Variant = _character_skills[character_id_variant]
		if not (raw_skill_data is Dictionary):
			continue
		serialized_skills[character_id] = _normalize_skill_data(raw_skill_data)
	return {
		"character_skills": serialized_skills,
	}


func load_state(data: Dictionary) -> void:
	_character_skills.clear()
	var raw_skills: Variant = data.get("character_skills", {})
	if not (raw_skills is Dictionary):
		return

	for character_id_variant in (raw_skills as Dictionary).keys():
		var character_id := str(character_id_variant).strip_edges()
		if character_id.is_empty():
			continue
		var skill_raw: Variant = (raw_skills as Dictionary)[character_id_variant]
		if not (skill_raw is Dictionary):
			continue
		_character_skills[character_id] = _normalize_skill_data(skill_raw)


func _find_recipe(catalog: Resource, recipe_id: String) -> Resource:
	if catalog == null:
		return null
	if catalog.has_method("find_recipe"):
		return catalog.find_recipe(StringName(recipe_id))
	return null


func _normalize_recipe(recipe: Resource) -> Dictionary:
	if recipe == null:
		return {}
	var recipe_type := str(_resource_get(recipe, "recipe_type", "")).to_lower().strip_edges()
	if not _is_supported_recipe_type(recipe_type):
		return {}
	var result_item_id := str(_resource_get(recipe, "result_item_id", "")).strip_edges()
	if result_item_id.is_empty():
		return {}
	var normalized_materials := _normalize_materials(_resource_get(recipe, "materials", []))
	if normalized_materials.is_empty():
		return {}
	var result_quantity := maxi(1, int(_resource_get(recipe, "result_quantity", 1)))
	var result_rarity_min := str(_resource_get(recipe, "result_rarity_min", "common")).to_lower().strip_edges()
	if _rarity_index(result_rarity_min) < 0:
		result_rarity_min = "common"

	return {
		"recipe_type": recipe_type,
		"result_item_id": result_item_id,
		"result_quantity": result_quantity,
		"result_rarity_min": result_rarity_min,
		"materials": normalized_materials,
		"required_skill_level": maxi(0, int(_resource_get(recipe, "required_skill_level", 0))),
		"success_rate_base": clampf(float(_resource_get(recipe, "success_rate_base", 0.0)), 0.0, 1.0),
	}


func _normalize_materials(raw_materials: Variant) -> Array[Dictionary]:
	if not (raw_materials is Array):
		return []
	var result: Array[Dictionary] = []
	for raw_material in raw_materials:
		if not (raw_material is Dictionary):
			continue
		var item_id := str((raw_material as Dictionary).get("item_id", "")).strip_edges()
		var quantity := int((raw_material as Dictionary).get("quantity", 0))
		if item_id.is_empty() or quantity <= 0:
			continue
		result.append({
			"item_id": item_id,
			"quantity": quantity,
		})
	return result


func _is_supported_recipe_type(recipe_type: String) -> bool:
	return recipe_type == RECIPE_TYPE_ALCHEMY or recipe_type == RECIPE_TYPE_FORGE


func _compute_success_rate(base_rate: float, material_quality_score: float, result_rarity_min: String, skill_level: int, required_skill_level: int) -> float:
	var min_index := maxi(0, _rarity_index(result_rarity_min))
	var material_bonus := maxf(0.0, material_quality_score - float(min_index)) * 0.05
	var skill_bonus := maxf(0.0, float(skill_level - required_skill_level)) * 0.06
	return clampf(base_rate + material_bonus + skill_bonus, 0.05, 0.98)


func _compute_output_rarity(material_quality_score: float, result_rarity_min: String, skill_level: int, required_skill_level: int, rng_source: Variant) -> String:
	var base_index := maxi(0, _rarity_index(result_rarity_min))
	var material_index := int(round(material_quality_score))
	var target_index := maxi(base_index, material_index)
	var skill_advantage := maxi(0, skill_level - required_skill_level)
	var material_advantage := maxf(0.0, material_quality_score - float(base_index))

	var up_chance := clampf(0.12 + float(skill_advantage) * 0.04 + material_advantage * 0.03, 0.12, 0.45)
	var down_chance := clampf(0.20 - float(skill_advantage) * 0.03, 0.03, 0.20)
	var roll := _roll_float(rng_source)
	if roll < down_chance:
		target_index -= 1
	elif roll > (1.0 - up_chance):
		target_index += 1

	target_index = clampi(target_index, base_index, RARITY_ORDER.size() - 1)
	return RARITY_ORDER[target_index]


func _calculate_material_quality_score(character_id: String, materials: Array[Dictionary], inventory_service: Node) -> float:
	if inventory_service == null or not inventory_service.has_method("get_inventory"):
		return 0.0
	var inventory: Array[Dictionary] = inventory_service.get_inventory(character_id)
	if inventory.is_empty():
		return 0.0

	var quality_sum := 0.0
	var quantity_sum := 0
	for material in materials:
		var material_item_id := str(material.get("item_id", ""))
		var required_quantity := int(material.get("quantity", 0))
		if required_quantity <= 0:
			continue
		var consumed := _sample_material_rarity_units(inventory, material_item_id, required_quantity)
		for rarity_index in consumed:
			quality_sum += float(rarity_index)
			quantity_sum += 1
	if quantity_sum <= 0:
		return 0.0
	return quality_sum / float(quantity_sum)


func _sample_material_rarity_units(inventory: Array[Dictionary], item_id: String, required_quantity: int) -> Array[int]:
	var result: Array[int] = []
	var remaining := required_quantity
	for index in range(inventory.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var record: Dictionary = inventory[index]
		if str(record.get("item_id", "")) != item_id:
			continue
		var record_quantity := maxi(0, int(record.get("quantity", 0)))
		if record_quantity <= 0:
			continue
		var rarity_index := maxi(0, _rarity_index(str(record.get("rarity", "common"))))
		var take := mini(remaining, record_quantity)
		for _i in range(take):
			result.append(rarity_index)
		remaining -= take
	return result


func _consume_materials_on_success(character_id: String, materials: Array[Dictionary], inventory_service: Node) -> Array[Dictionary]:
	var consumed: Array[Dictionary] = []
	for material in materials:
		var item_id := str(material.get("item_id", ""))
		var quantity := int(material.get("quantity", 0))
		if quantity <= 0:
			continue
		if inventory_service.has_method("remove_item"):
			var removed := bool(inventory_service.remove_item(character_id, item_id, quantity))
			if removed:
				consumed.append({
					"item_id": item_id,
					"quantity": quantity,
				})
	return consumed


func _consume_materials_on_failure(character_id: String, materials: Array[Dictionary], inventory_service: Node) -> Array[Dictionary]:
	var lost: Array[Dictionary] = []
	for material in materials:
		var item_id := str(material.get("item_id", ""))
		var quantity := int(material.get("quantity", 0))
		if quantity <= 0:
			continue
		var loss_quantity := maxi(1, int(ceil(float(quantity) * FAILURE_MATERIAL_LOSS_RATIO)))
		if inventory_service.has_method("remove_item"):
			var removed := bool(inventory_service.remove_item(character_id, item_id, loss_quantity))
			if removed:
				lost.append({
					"item_id": item_id,
					"quantity": loss_quantity,
				})
	return lost


func _resolve_loot_rng(fallback_rng: SeededRandom) -> Variant:
	if _rng_channels != null and _rng_channels.has_method("get_loot_rng"):
		var rng = _rng_channels.get_loot_rng()
		if rng != null:
			return rng
	return fallback_rng


func _roll_float(rng_source: Variant) -> float:
	if rng_source == null:
		return randf()
	if rng_source is RandomNumberGenerator:
		return (rng_source as RandomNumberGenerator).randf()
	if rng_source is SeededRandom:
		return (rng_source as SeededRandom).next_float()
	if rng_source is Object and rng_source.has_method("next_float"):
		return float(rng_source.next_float())
	if rng_source is Object and rng_source.has_method("randf"):
		return float(rng_source.randf())
	return randf()


func _rarity_index(rarity: String) -> int:
	var index := RARITY_ORDER.find(rarity)
	if index == -1:
		return 0
	return index


func _resolve_inventory_service() -> Node:
	if is_instance_valid(_inventory_service):
		return _inventory_service
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop
		if scene_tree.root != null:
			var node := scene_tree.root.get_node_or_null("InventoryService")
			if node != null:
				_inventory_service = node
				return _inventory_service
	return null


func _get_or_create_character_skill_data(character_id: String) -> Dictionary:
	if not _character_skills.has(character_id):
		var initial := {
			RECIPE_TYPE_ALCHEMY: 1,
			RECIPE_TYPE_FORGE: 1,
		}
		_character_skills[character_id] = initial
		return initial
	var raw_data: Variant = _character_skills[character_id]
	var normalized := _normalize_skill_data(raw_data)
	_character_skills[character_id] = normalized
	return normalized


func _normalize_skill_data(raw_data: Variant) -> Dictionary:
	if not (raw_data is Dictionary):
		return {
			RECIPE_TYPE_ALCHEMY: 1,
			RECIPE_TYPE_FORGE: 1,
		}
	var data: Dictionary = raw_data
	return {
		RECIPE_TYPE_ALCHEMY: maxi(0, int(data.get(RECIPE_TYPE_ALCHEMY, 1))),
		RECIPE_TYPE_FORGE: maxi(0, int(data.get(RECIPE_TYPE_FORGE, 1))),
	}


func _emit_event(event_name: StringName, trace: Dictionary) -> void:
	if _event_log == null or not _event_log.has_method("add_event"):
		return
	_event_log.add_event({
		"category": "crafting",
		"title": str(event_name),
		"direct_cause": str(event_name),
		"result": "crafting_event",
		"trace": _duplicate_dict(trace),
	})


func _result(success: bool, reason: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"success": success,
		"reason": reason,
	}
	for key in extra.keys():
		result[str(key)] = extra[key]
	return result


func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value


func _duplicate_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _duplicate_array_dict(value: Variant) -> Array[Dictionary]:
	if not (value is Array):
		return []
	var result: Array[Dictionary] = []
	for entry in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result

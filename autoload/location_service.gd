extends Node

const WorldDataCatalogScript = preload("res://scripts/resources/world_data_catalog.gd")

signal moved(character_id: StringName, from_region_id: StringName, to_region_id: StringName)

const ERROR_CHARACTER_NOT_FOUND := "character_not_found"
const ERROR_TARGET_REGION_NOT_FOUND := "target_region_not_found"
const ERROR_SOURCE_REGION_NOT_FOUND := "source_region_not_found"
const ERROR_NON_ADJACENT_MOVE := "non_adjacent_move"

var _catalog: Resource
var _runtime_characters: Array[Dictionary] = []


func bind_runtime(catalog: Resource, runtime_characters: Array[Dictionary]) -> void:
	_catalog = catalog
	_runtime_characters = runtime_characters


func clear_runtime() -> void:
	_catalog = null
	_runtime_characters = []


func get_character_region(character_id: StringName) -> StringName:
	var resolved_id := str(character_id)
	if resolved_id.is_empty():
		return &""
	for character in _runtime_characters:
		if str(character.get("id", "")) == resolved_id:
			return StringName(str(character.get("region_id", "")))
	return &""


func set_character_region(character_id: StringName, target_region_id: StringName) -> Dictionary:
	var resolved_character_id := str(character_id)
	var resolved_target_region_id := str(target_region_id)
	if resolved_character_id.is_empty():
		return _result(false, ERROR_CHARACTER_NOT_FOUND, {
			"character_id": resolved_character_id,
		})
	if resolved_target_region_id.is_empty() or _find_region(resolved_target_region_id) == null:
		return _result(false, ERROR_TARGET_REGION_NOT_FOUND, {
			"character_id": resolved_character_id,
			"target_region_id": resolved_target_region_id,
		})

	for index in range(_runtime_characters.size()):
		var character: Dictionary = _runtime_characters[index]
		if str(character.get("id", "")) != resolved_character_id:
			continue

		var from_region_id := str(character.get("region_id", ""))
		if from_region_id == resolved_target_region_id:
			return _result(true, "ok", {
				"character_id": resolved_character_id,
				"from_region_id": from_region_id,
				"to_region_id": resolved_target_region_id,
				"changed": false,
			})

		var from_region := _find_region(from_region_id)
		if from_region == null:
			return _result(false, ERROR_SOURCE_REGION_NOT_FOUND, {
				"character_id": resolved_character_id,
				"from_region_id": from_region_id,
				"to_region_id": resolved_target_region_id,
			})

		if not _is_adjacent(from_region, resolved_target_region_id):
			return _result(false, ERROR_NON_ADJACENT_MOVE, {
				"character_id": resolved_character_id,
				"from_region_id": from_region_id,
				"to_region_id": resolved_target_region_id,
			})

		character["region_id"] = resolved_target_region_id
		_runtime_characters[index] = character
		moved.emit(StringName(resolved_character_id), StringName(from_region_id), StringName(resolved_target_region_id))
		return _result(true, "ok", {
			"character_id": resolved_character_id,
			"from_region_id": from_region_id,
			"to_region_id": resolved_target_region_id,
			"changed": true,
		})

	return _result(false, ERROR_CHARACTER_NOT_FOUND, {
		"character_id": resolved_character_id,
	})


func _is_adjacent(from_region: Resource, target_region_id: String) -> bool:
	if from_region == null:
		return false
	var adjacent_ids := from_region.get("adjacent_region_ids") as PackedStringArray
	for adjacent_id in adjacent_ids:
		if str(adjacent_id) == target_region_id:
			return true
	return false


func _find_region(region_id: String) -> Resource:
	if region_id.is_empty() or _catalog == null or not _catalog.has_method("find_region"):
		return null
	return _catalog.find_region(StringName(region_id))


func get_all_regions(mode: StringName = &"") -> Array[Dictionary]:
	if _catalog == null:
		return []

	var regions_data: Array = []
	var typed_catalog := _catalog as WorldDataCatalog
	if typed_catalog != null:
		regions_data = typed_catalog.regions
	elif _catalog.has_method("get"):
		var raw_regions: Variant = _catalog.get("regions")
		if raw_regions is Array:
			regions_data = raw_regions
	if regions_data.is_empty():
		return []

	var result: Array[Dictionary] = []
	
	for region_res in regions_data:
		if region_res == null:
			continue
		
		var region_id := str(_resource_get(region_res, "id", ""))
		if region_id.is_empty():
			continue
			
		var human_visible := bool(_resource_get(region_res, "human_visible", true))
		var deity_visible := bool(_resource_get(region_res, "deity_visible", true))
		
		if mode == &"human" and not human_visible:
			continue
		if mode == &"deity" and not deity_visible:
			continue
			
		var parent_id := str(_resource_get(region_res, "parent_region_id", ""))
		var adj_ids_raw: Variant = _resource_get(region_res, "adjacent_region_ids", PackedStringArray())
		var adj_ids: PackedStringArray = PackedStringArray()
		if adj_ids_raw != null:
			if typeof(adj_ids_raw) == TYPE_PACKED_STRING_ARRAY:
				for id in adj_ids_raw:
					adj_ids.append(str(id))
			elif typeof(adj_ids_raw) == TYPE_ARRAY:
				for id in adj_ids_raw:
					adj_ids.append(str(id))
				
		result.append({
			"id": region_id,
			"display_name": str(_resource_get(region_res, "display_name", "")),
			"summary": str(_resource_get(region_res, "summary", "")),
			"parent_region_id": parent_id,
			"adjacent_region_ids": adj_ids,
			"human_visible": human_visible,
			"deity_visible": deity_visible
		})
		
	return result


func _result(ok: bool, error_code: String, context: Dictionary = {}) -> Dictionary:
	return {
		"ok": ok,
		"error": error_code,
		"context": context.duplicate(true),
	}


func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	return fallback if value == null else value

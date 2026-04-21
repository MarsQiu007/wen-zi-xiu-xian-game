extends Resource
class_name WorldDataCatalog

@export var characters: Array[Resource] = []
@export var families: Array[Resource] = []
@export var factions: Array[Resource] = []
@export var regions: Array[Resource] = []
@export var event_templates: Array[Resource] = []
@export var doctrines: Array[Resource] = []
@export var deities: Array[Resource] = []
@export var items: Array[Resource] = []
@export var techniques: Array[Resource] = []
@export var crafting_recipes: Array[Resource] = []
@export var recipes: Array[Resource] = []
@export var loot_tables: Array[Resource] = []


func find_character(character_id: StringName) -> Resource:
	for character in characters:
		if character != null and character.get("id") == character_id:
			return character
	return null


func find_family(family_id: StringName) -> Resource:
	for family in families:
		if family != null and family.get("id") == family_id:
			return family
	return null


func find_faction(faction_id: StringName) -> Resource:
	for faction in factions:
		if faction != null and faction.get("id") == faction_id:
			return faction
	return null


func find_region(region_id: StringName) -> Resource:
	for region in regions:
		if region != null and region.get("id") == region_id:
			return region
	return null


func find_event_template(event_template_id: StringName) -> Resource:
	for event_template in event_templates:
		if event_template != null and event_template.get("id") == event_template_id:
			return event_template
	return null


func find_doctrine(doctrine_id: StringName) -> Resource:
	for doctrine in doctrines:
		if doctrine != null and doctrine.get("id") == doctrine_id:
			return doctrine
	return null


func find_deity(deity_id: StringName) -> Resource:
	for deity in deities:
		if deity != null and deity.get("id") == deity_id:
			return deity
	return null


func find_item(item_id: StringName) -> Resource:
	for item in items:
		if item != null and item.get("id") == item_id:
			return item
	return null


func get_item(item_id: StringName) -> Resource:
	return find_item(item_id)


func find_technique(technique_id: StringName) -> Resource:
	for technique in techniques:
		if technique != null and technique.get("id") == technique_id:
			return technique
	return null


func get_technique(technique_id: StringName) -> Resource:
	return find_technique(technique_id)


func get_techniques_by_sect(sect_id: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var sect_id_normalized := sect_id.strip_edges()
	for technique in techniques:
		if technique == null:
			continue
		var technique_sect_id := String(technique.get("sect_exclusive_id")).strip_edges()
		if technique_sect_id.is_empty():
			result.append(technique)
		elif not sect_id_normalized.is_empty() and technique_sect_id == sect_id_normalized:
			result.append(technique)
	return result


func find_recipe(recipe_id: StringName) -> Resource:
	for recipe in get_crafting_recipes():
		if recipe != null and recipe.get("id") == recipe_id:
			return recipe
	return null


func get_recipe(recipe_id: StringName) -> Resource:
	return find_recipe(recipe_id)


func get_crafting_recipes() -> Array[Resource]:
	if not crafting_recipes.is_empty():
		return crafting_recipes
	return recipes


func get_recipes() -> Array[Resource]:
	return get_crafting_recipes()


func get_recipes_by_type(recipe_type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var recipe_type_normalized := recipe_type.strip_edges()
	if recipe_type_normalized.is_empty():
		return result
	for recipe in get_crafting_recipes():
		if recipe == null:
			continue
		var value := String(recipe.get("recipe_type")).strip_edges()
		if value == recipe_type_normalized:
			result.append(recipe)
	return result


func find_loot_table(loot_table_id: StringName) -> Resource:
	for loot_table in loot_tables:
		if loot_table != null and loot_table.get("id") == loot_table_id:
			return loot_table
	return null


func get_loot_table(loot_table_id: StringName) -> Resource:
	return find_loot_table(loot_table_id)


func get_loot_tables_by_region_tag(region_tag: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var region_tag_normalized := region_tag.strip_edges()
	if region_tag_normalized.is_empty():
		return result
	for loot_table in loot_tables:
		if loot_table == null:
			continue
		var region_tags_value: Variant = loot_table.get("region_tags")
		if region_tags_value is PackedStringArray and (region_tags_value as PackedStringArray).has(region_tag_normalized):
			result.append(loot_table)
			continue
		if region_tags_value is Array[String] and (region_tags_value as Array[String]).has(region_tag_normalized):
			result.append(loot_table)
			continue
		if region_tags_value is Array:
			for tag_value in (region_tags_value as Array):
				if String(tag_value).strip_edges() == region_tag_normalized:
					result.append(loot_table)
					break
	return result


func get_items_by_type(item_type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var item_type_normalized := item_type.strip_edges()
	if item_type_normalized.is_empty():
		return result
	for item in items:
		if item == null:
			continue
		var value := String(item.get("item_type")).strip_edges()
		if value == item_type_normalized:
			result.append(item)
	return result


func validate_required_fields() -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	issues.append_array(_validate_collection(characters, "character"))
	issues.append_array(_validate_collection(families, "family"))
	issues.append_array(_validate_collection(factions, "faction"))
	issues.append_array(_validate_collection(regions, "region"))
	issues.append_array(_validate_collection(event_templates, "event template"))
	issues.append_array(_validate_collection(doctrines, "doctrine"))
	issues.append_array(_validate_collection(deities, "deity"))
	issues.append_array(_validate_collection(items, "item"))
	if items.is_empty():
		issues.append("%s 集合为空" % "item")
	issues.append_array(_validate_collection(techniques, "technique"))
	if techniques.is_empty():
		issues.append("%s 集合为空" % "technique")
	issues.append_array(_validate_collection(get_crafting_recipes(), "recipe"))
	if get_crafting_recipes().is_empty():
		issues.append("%s 集合为空" % "recipe")
	issues.append_array(_validate_collection(loot_tables, "loot table"))
	if loot_tables.is_empty():
		issues.append("%s 集合为空" % "loot table")
	return issues


func _validate_collection(collection_items: Array[Resource], kind: String) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var seen_ids: Dictionary = {}
	for item in collection_items:
		if item == null:
			issues.append("%s 资源存在空引用" % kind)
			continue
		var item_id = item.get("id")
		var item_name = item.get("display_name")
		var item_id_string := String(item_id)
		if item_id == null or String(item_id).is_empty():
			issues.append("%s 缺少 id: %s" % [kind, String(item_name)])
		if item_name == null or String(item_name).is_empty():
			issues.append("%s 缺少 display_name: %s" % [kind, String(item_id)])
		if not item_id_string.is_empty() and seen_ids.has(item_id_string):
			issues.append("%s 存在重复 id: %s" % [kind, item_id_string])
		elif not item_id_string.is_empty():
			seen_ids[item_id_string] = true
	return issues

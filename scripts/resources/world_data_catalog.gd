extends Resource
class_name WorldDataCatalog

@export var characters: Array[Resource] = []
@export var families: Array[Resource] = []
@export var factions: Array[Resource] = []
@export var regions: Array[Resource] = []
@export var event_templates: Array[Resource] = []
@export var doctrines: Array[Resource] = []
@export var deities: Array[Resource] = []


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


func validate_required_fields() -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	issues.append_array(_validate_collection(characters, "character"))
	issues.append_array(_validate_collection(families, "family"))
	issues.append_array(_validate_collection(factions, "faction"))
	issues.append_array(_validate_collection(regions, "region"))
	issues.append_array(_validate_collection(event_templates, "event template"))
	issues.append_array(_validate_collection(doctrines, "doctrine"))
	issues.append_array(_validate_collection(deities, "deity"))
	return issues


func _validate_collection(items: Array[Resource], kind: String) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	for item in items:
		if item == null:
			issues.append("%s 资源存在空引用" % kind)
			continue
		var item_id = item.get("id")
		var item_name = item.get("display_name")
		if item_id == null or String(item_id).is_empty():
			issues.append("%s 缺少 id: %s" % [kind, String(item_name)])
		if item_name == null or String(item_name).is_empty():
			issues.append("%s 缺少 display_name: %s" % [kind, String(item_id)])
	return issues

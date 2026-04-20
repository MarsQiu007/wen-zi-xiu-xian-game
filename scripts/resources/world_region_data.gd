extends Resource
class_name WorldRegionData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var human_visible: bool = true
@export var deity_visible: bool = true
@export var region_type: StringName = &"region"
@export var parent_region_id: StringName = &""
@export var adjacent_region_ids: PackedStringArray = PackedStringArray()
@export var controlling_faction_id: StringName = &""
@export var active_population_hint: int = 0
@export var resource_tags: PackedStringArray = PackedStringArray()
@export var danger_tags: PackedStringArray = PackedStringArray()
@export var key_site_tags: PackedStringArray = PackedStringArray()
@export var event_pool_id: StringName = &""
@export_multiline var region_notes: String = ""

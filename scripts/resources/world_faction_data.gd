extends Resource
class_name WorldFactionData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var human_visible: bool = true
@export var deity_visible: bool = true
@export var faction_type: StringName = &"mortal"
@export var faction_tier: StringName = &"mortal"
@export var headquarters_region_id: StringName = &""
@export var associated_doctrine_id: StringName = &""
@export var patron_deity_id: StringName = &""
@export var influence: int = 0
@export var doctrine_alignment_tags: PackedStringArray = PackedStringArray()
@export var territory_region_ids: PackedStringArray = PackedStringArray()
@export_multiline var relations_summary: String = ""

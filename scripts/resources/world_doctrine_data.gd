extends Resource
class_name WorldDoctrineData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var human_visible: bool = true
@export var deity_visible: bool = true
@export var doctrine_type: StringName = &"orthodox"
@export var authority_scope: StringName = &"local"
@export var associated_faction_id: StringName = &""
@export var associated_deity_id: StringName = &""
@export var core_tenets: PackedStringArray = PackedStringArray()
@export var taboo_tags: PackedStringArray = PackedStringArray()
@export var support_tags: PackedStringArray = PackedStringArray()
@export_multiline var doctrine_notes: String = ""

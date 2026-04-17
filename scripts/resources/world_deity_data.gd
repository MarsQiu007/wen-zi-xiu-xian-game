extends Resource
class_name WorldDeityData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var human_visible: bool = true
@export var deity_visible: bool = true
@export var deity_type: StringName = &"local_deity"
@export var domain_tags: PackedStringArray = PackedStringArray()
@export var worship_style_tags: PackedStringArray = PackedStringArray()
@export var manifestation_tags: PackedStringArray = PackedStringArray()
@export var preferred_doctrine_id: StringName = &""
@export var faith_income_hint: int = 0
@export var manifestation_scope: StringName = &"local"
@export_multiline var divine_goal_summary: String = ""

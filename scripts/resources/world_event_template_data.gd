extends Resource
class_name WorldEventTemplateData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var human_visible: bool = true
@export var deity_visible: bool = true
@export var event_type: StringName = &"world"
@export var region_scope_tags: PackedStringArray = PackedStringArray()
@export var required_actor_tags: PackedStringArray = PackedStringArray()
@export var required_faction_tags: PackedStringArray = PackedStringArray()
@export var trigger_tags: PackedStringArray = PackedStringArray()
@export var result_tags: PackedStringArray = PackedStringArray()
@export var severity: int = 0
@export var key_participant_roles: PackedStringArray = PackedStringArray()
@export var pause_behavior: StringName = &"auto"
@export_multiline var summary_template: String = ""

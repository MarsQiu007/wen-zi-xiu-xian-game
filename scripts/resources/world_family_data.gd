extends Resource
class_name WorldFamilyData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var human_visible: bool = true
@export var deity_visible: bool = true
@export var seat_region_id: StringName = &""
@export var patron_faction_id: StringName = &""
@export var inheritance_rule: StringName = &"direct_descendant_first"
@export var prestige: int = 0
@export var bloodline_strength: int = 0
@export var notable_member_ids: PackedStringArray = PackedStringArray()
@export_multiline var legacy_notes: String = ""

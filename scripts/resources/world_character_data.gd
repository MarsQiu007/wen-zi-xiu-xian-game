extends Resource
class_name WorldCharacterData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var human_visible: bool = true
@export var deity_visible: bool = true
@export var family_id: StringName = &""
@export var faction_id: StringName = &""
@export var region_id: StringName = &""
@export var age_years: int = 0
@export var life_stage: StringName = &"ordinary"
@export var cultivation_stage: StringName = &"凡人"
@export var inheritance_priority: int = 0
@export var talent_rank: int = 0
@export var morality_tags: PackedStringArray = PackedStringArray()
@export var temperament_tags: PackedStringArray = PackedStringArray()
@export var faith_affinity: int = 0
@export var role_tags: PackedStringArray = PackedStringArray()
@export_multiline var life_goal_summary: String = ""
@export var spouse_character_id: StringName = &""
@export var dao_companion_character_id: StringName = &""
@export var direct_line_child_ids: PackedStringArray = PackedStringArray()
@export var legal_heir_character_id: StringName = &""
